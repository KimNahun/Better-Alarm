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
                    Text("weekly_title")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Color.pTextPrimary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

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
        .pActionSheet(
            isPresented: Binding(
                get: { viewModel.pendingDisableAlarm != nil },
                set: { if !$0 { viewModel.cancelDisable() } }
            ),
            title: String(localized: "weekly_disable_action_title"),
            items: viewModel.pendingDisableAlarm.map { alarm in [
                PActionSheetItem(title: String(localized: "weekly_disable_action_skip_once"), icon: "forward.fill") {
                    Task { await viewModel.skipOnceAndDisable(alarm) }
                },
                PActionSheetItem(title: String(localized: "weekly_disable_action_disable_full"), icon: "bell.slash.fill", role: .destructive) {
                    Task { await viewModel.confirmDisable(alarm) }
                }
            ]} ?? []
        )
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
                AlarmRowView(alarm: alarm, onToggle: { desiredOn in
                    Task {
                        viewModel.requestToggleVisualState(alarm, desiredOn: desiredOn)
                        HapticManager.selection()
                    }
                }, onTap: {
                    selectedAlarm = alarm
                    showDetail = true
                    HapticManager.impact(.light)
                })
                .pLoadingOverlay(isLoading: .constant(viewModel.togglingAlarmID == alarm.id))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
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

            Text("weekly_empty_title")
                .font(.title3.weight(.medium))
                .foregroundStyle(Color.pTextSecondary)

            Text("weekly_empty_subtitle")
                .font(.body)
                .foregroundStyle(Color.pTextTertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("weekly_empty_a11y"))
    }
}
