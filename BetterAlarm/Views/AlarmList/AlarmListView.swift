import SwiftUI
import PersonalColorDesignSystem

// MARK: - AlarmListView

/// 알람 목록 화면.
/// 상단 "알람" 타이틀 + "다음 알람" 배너는 고정, 아래 알람 리스트만 스크롤.
struct AlarmListView: View {
    @State private var viewModel: AlarmListViewModel
    private let store: AlarmStore
    @State private var showDetail: Bool = false
    @State private var selectedAlarm: Alarm? = nil
    @Environment(\.pThemeColors) private var theme

    init(store: AlarmStore) {
        self.store = store
        _viewModel = State(initialValue: AlarmListViewModel(store: store))
    }

    var body: some View {
        ZStack {
            PGradientBackground()

            VStack(spacing: 0) {
                // ── 고정 헤더 영역 (스크롤 안됨) ──
                header
                nextAlarmBanner

                // ── 스크롤 가능 영역 (알람 리스트만) ──
                if viewModel.alarms.isEmpty && !viewModel.isLoading {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.alarms, id: \.id) { alarm in
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
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .animation(.easeInOut(duration: 0.3), value: viewModel.alarms)
                    }
                }
            }
        }
        .pLoadingOverlay(isLoading: Binding(get: { viewModel.isLoading }, set: { _ in }))
        .sheet(isPresented: $showDetail, onDismiss: {
            // E14 수정: 시트 닫힘 후 selectedAlarm 초기화.
            // showSaveToast 판정은 클로저 캡처 시점에 결정되므로 onDismiss 초기화는 안전.
            selectedAlarm = nil
        }) {
            let wasEditing = selectedAlarm != nil
            AlarmDetailView(
                store: store,
                editingAlarm: selectedAlarm
            ) {
                Task {
                    await viewModel.loadAlarms()
                    viewModel.showSaveToast(isEditing: wasEditing)
                }
            } onDeleted: {
                Task {
                    await viewModel.loadAlarms()
                    viewModel.showDeleteToast()
                }
            }
        }
        .task {
            await viewModel.loadAlarms()
        }
        .onAppear {
            Task { await viewModel.loadAlarms() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .alarmCompleted)) { _ in
            Task { await viewModel.loadAlarms() }
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

    // MARK: - Fixed Header

    private var header: some View {
        HStack {
            Text("alarm_list_title")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Color.pTextPrimary)
            Spacer()
            Button {
                selectedAlarm = nil
                showDetail = true
                HapticManager.impact(.light)
            } label: {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.accentPrimary)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel(Text("alarm_list_add_button_a11y"))
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Next Alarm Banner

    @ViewBuilder
    private var nextAlarmBanner: some View {
        if let display = viewModel.nextAlarmDisplayString {
            GlassCard {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("alarm_list_next_alarm_label")
                            .font(.caption)
                            .foregroundStyle(Color.pTextTertiary)
                        Text(display)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.pTextPrimary)
                    }
                    Spacer()
                    Image(systemName: "alarm.fill")
                        .font(.title3)
                        .foregroundStyle(theme.accentPrimary)
                }
                .padding(16)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("alarm_list_next_alarm_a11y \(display)"))
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "alarm")
                .font(.largeTitle)
                .foregroundStyle(Color.pTextTertiary)

            Text("alarm_list_empty_title")
                .font(.title3.weight(.medium))
                .foregroundStyle(Color.pTextSecondary)

            Text("alarm_list_empty_subtitle")
                .font(.body)
                .foregroundStyle(Color.pTextTertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("alarm_list_empty_a11y"))
    }
}
