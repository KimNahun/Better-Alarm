import SwiftUI
import PersonalColorDesignSystem

// MARK: - WeeklyAlarmView

/// 주간 반복 알람만 필터링하여 표시하는 화면.
/// AlarmRowView를 재사용하며 swipeActions로 삭제/건너뛰기를 지원한다.
/// MVVM: View는 UI 선언만. 비즈니스 로직은 WeeklyAlarmViewModel에 위임.
struct WeeklyAlarmView: View {
    @State private var viewModel: WeeklyAlarmViewModel
    private let store: AlarmStore
    @State private var selectedAlarm: Alarm? = nil
    @State private var showDetail: Bool = false
    @Environment(\.pThemeColors) private var theme

    init(store: AlarmStore) {
        self.store = store
        _viewModel = State(initialValue: WeeklyAlarmViewModel(store: store))
    }

    var body: some View {
        ZStack {
            PGradientBackground()

            VStack(spacing: 0) {
                // 고정 헤더
                HStack {
                    Text("주간 알람")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Color.pTextPrimary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)

                dayTabs

                if viewModel.filteredAlarms.isEmpty {
                    emptyState
                } else {
                    weeklyAlarmList
                }
            }
        }
        .sheet(isPresented: $showDetail) {
            if let alarm = selectedAlarm {
                AlarmDetailView(
                    store: store,
                    editingAlarm: alarm
                ) {
                    Task { await viewModel.loadAlarms() }
                }
            }
        }
        .task {
            await viewModel.loadAlarms()
        }
        .toast(
            isPresented: Binding(
                get: { viewModel.showToast },
                set: { if !$0 { viewModel.dismissToast() } }
            ),
            message: viewModel.toastMessage,
            type: .info
        )
        .confirmationDialog(
            "주간 알람 처리",
            isPresented: Binding(
                get: { viewModel.pendingDisableAlarm != nil },
                set: { if !$0 { viewModel.cancelDisable() } }
            ),
            titleVisibility: .visible
        ) {
            if let alarm = viewModel.pendingDisableAlarm {
                Button("이번만 스킵") {
                    Task { await viewModel.skipOnceAndDisable(alarm) }
                }
                Button("완전히 끄기", role: .destructive) {
                    Task { await viewModel.confirmDisable(alarm) }
                }
                Button("취소", role: .cancel) {
                    viewModel.cancelDisable()
                }
            }
        } message: {
            Text("이 주간 알람을 어떻게 처리할까요?")
        }
    }

    // MARK: - Day Tabs

    private var dayTabs: some View {
        HStack(spacing: 8) {
            ForEach(Weekday.allCases, id: \.self) { day in
                Button {
                    if viewModel.selectedDay == day {
                        viewModel.selectedDay = nil
                    } else {
                        viewModel.selectedDay = day
                    }
                } label: {
                    let isSelected = viewModel.selectedDay == day
                    Text(day.shortName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? .white : Color.pTextTertiary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(isSelected ? theme.accentPrimary : Color.pGlassFill)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    // MARK: - Subviews

    private var weeklyAlarmList: some View {
        List {
            ForEach(viewModel.filteredAlarms) { alarm in
                AlarmRowView(alarm: alarm) { enabled in
                    Task {
                        viewModel.requestToggle(alarm, enabled: enabled)
                        HapticManager.selection()
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedAlarm = alarm
                    showDetail = true
                    HapticManager.impact(.light)
                }
                .alarmSwipeActions(
                    alarm: alarm,
                    onDelete: { Task { await viewModel.deleteAlarm(alarm) } },
                    onSkip: { Task { await viewModel.skipOnceAlarm(alarm) } },
                    onClearSkip: { Task { await viewModel.clearSkip(alarm) } }
                )
            }
        }
        .listStyle(.plain)
        .background(Color.clear)
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "calendar")
                .font(.largeTitle)
                .foregroundStyle(Color.pTextTertiary)

            Text("주간 반복 알람이 없습니다")
                .font(.title3.weight(.medium))
                .foregroundStyle(Color.pTextSecondary)

            Text("알람 탭에서 주간 반복 알람을 추가하세요")
                .font(.body)
                .foregroundStyle(Color.pTextTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("주간 반복 알람이 없습니다. 알람 탭에서 주간 반복 알람을 추가하세요.")
    }
}
