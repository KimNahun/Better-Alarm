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
                .padding(.top, 8)

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
    }

    // MARK: - Day Tabs

    private var dayTabs: some View {
        HStack(spacing: 4) {
            // 전체 탭
            Button { viewModel.selectedDay = nil } label: {
                Text("전체")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(viewModel.selectedDay == nil ? .white : Color.pTextTertiary)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(viewModel.selectedDay == nil ? Color.pAccentPrimary : Color.pGlassFill)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            ForEach(Weekday.allCases, id: \.self) { day in
                Button { viewModel.selectedDay = day } label: {
                    Text(day.shortName)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(viewModel.selectedDay == day ? .white : Color.pTextTertiary)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(viewModel.selectedDay == day ? Color.pAccentPrimary : Color.pGlassFill)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Subviews

    private var weeklyAlarmList: some View {
        List {
            ForEach(viewModel.filteredAlarms) { alarm in
                AlarmRowView(alarm: alarm) { enabled in
                    Task {
                        await viewModel.toggleAlarm(alarm, enabled: enabled)
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
