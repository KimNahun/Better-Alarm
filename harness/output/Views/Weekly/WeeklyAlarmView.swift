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
        NavigationStack {
            ZStack {
                PGradientBackground()

                VStack(spacing: 0) {
                    if viewModel.weeklyAlarms.isEmpty {
                        emptyState
                    } else {
                        weeklyAlarmList
                    }
                }
            }
            .navigationTitle("주간 알람")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
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
        }
        .task {
            await viewModel.loadAlarms()
        }
    }

    // MARK: - Subviews

    private var weeklyAlarmList: some View {
        List {
            ForEach(viewModel.weeklyAlarms) { alarm in
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
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        Task {
                            await viewModel.deleteAlarm(alarm)
                            HapticManager.notification(.success)
                        }
                    } label: {
                        Label("삭제", systemImage: "trash.fill")
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    if alarm.isEnabled {
                        if alarm.isSkippingNext {
                            Button {
                                Task { await viewModel.clearSkip(alarm) }
                            } label: {
                                Label("건너뛰기 취소", systemImage: "arrow.uturn.backward")
                            }
                            .tint(Color.pWarning)
                        } else {
                            Button {
                                Task {
                                    await viewModel.skipOnceAlarm(alarm)
                                    HapticManager.impact(.medium)
                                }
                            } label: {
                                Label("1회 건너뛰기", systemImage: "forward.fill")
                            }
                            .tint(Color.pAccentSecondary)
                        }
                    }
                }
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
