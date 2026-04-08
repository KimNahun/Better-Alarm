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
        NavigationStack {
            ZStack {
                PGradientBackground()

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

                    // 알람 목록 (스크롤 가능 영역)
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView()
                            .tint(Color.pAccentPrimary)
                            .scaleEffect(1.2)
                        Spacer()
                    } else if viewModel.alarms.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(viewModel.alarms) { alarm in
                                    AlarmRowView(alarm: alarm) { enabled in
                                        Task {
                                            await viewModel.toggleAlarm(alarm, enabled: enabled)
                                            HapticManager.selection()
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedAlarm = alarm
                                        showDetail = true
                                        HapticManager.impact(.light)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("알람")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
                    Task {
                        await viewModel.loadAlarms()
                        viewModel.showSaveToast(isEditing: selectedAlarm != nil)
                    }
                }
            }
        }
        .task {
            await viewModel.loadAlarms()
        }
        .onAppear {
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

    // alarmList는 인라인으로 ScrollView + LazyVStack으로 이동됨

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
