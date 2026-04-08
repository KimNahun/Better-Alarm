import SwiftUI
import PersonalColorDesignSystem

// MARK: - AlarmListView

/// 알람 목록 화면. NavigationStack 루트.
/// MVVM: View는 UI 선언만. 비즈니스 로직은 ViewModel로.
struct AlarmListView: View {
    @State private var viewModel: AlarmListViewModel
    private let store: AlarmStore  // AlarmDetailView 생성 시 주입용
    @State private var showDetail: Bool = false
    @State private var selectedAlarm: Alarm? = nil

    init(store: AlarmStore) {
        self.store = store
        _viewModel = State(initialValue: AlarmListViewModel(store: store))
    }

    var body: some View {
        ZStack {
            // 배경 그래디언트 (PersonalColorDesignSystem)
            GradientBackground()
                .ignoresSafeArea()

            NavigationStack {
                VStack(spacing: 0) {
                    // 에러 메시지 표시
                    if let errorMessage = viewModel.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color.pWarning)
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(Color.pWarning)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }

                    // 다음 알람 표시
                    nextAlarmBanner

                    // 알람 목록
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView()
                            .tint(Color.pAccentPrimary)
                            .scaleEffect(1.2)
                        Spacer()
                    } else if viewModel.alarms.isEmpty {
                        emptyState
                    } else {
                        alarmList
                    }
                }
                .navigationTitle("알람")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            selectedAlarm = nil
                            showDetail = true
                            HapticManager.impact(.light)
                        } label: {
                            Image(systemName: "plus")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(Color.pAccentPrimary)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .accessibilityLabel("새 알람 추가")
                    }
                }
                .sheet(isPresented: $showDetail) {
                    AlarmDetailView(
                        store: store,
                        editingAlarm: selectedAlarm
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

    @ViewBuilder
    private var nextAlarmBanner: some View {
        if let display = viewModel.nextAlarmDisplayString {
            GlassCard {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("다음 알람")
                            .font(.caption)
                            .foregroundStyle(Color.pTextTertiary)
                        Text(display)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.pTextPrimary)
                    }
                    Spacer()
                    Image(systemName: "alarm.fill")
                        .font(.title3)
                        .foregroundStyle(Color.pAccentPrimary)
                }
                .padding(16)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("다음 알람: \(display)")
        }
    }

    private var alarmList: some View {
        List {
            ForEach(viewModel.alarms) { alarm in
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
                    if alarm.isWeeklyAlarm && alarm.isEnabled {
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
            Image(systemName: "alarm")
                .font(.largeTitle)
                .foregroundStyle(Color.pTextTertiary)

            Text("설정된 알람이 없습니다")
                .font(.title3.weight(.medium))
                .foregroundStyle(Color.pTextSecondary)

            Text("+ 버튼을 눌러 첫 알람을 추가하세요")
                .font(.body)
                .foregroundStyle(Color.pTextTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("설정된 알람이 없습니다. + 버튼을 눌러 첫 알람을 추가하세요.")
    }
}
