import SwiftUI
import PersonalColorDesignSystem

// MARK: - SettingsView

/// 설정 화면. Form 기반 UI로 Live Activity 토글, AlarmKit 권한 상태, 앱 정보를 표시.
/// MVVM: View는 UI 선언만. 비즈니스 로직은 SettingsViewModel에 위임.
struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    @State private var liveActivityToggle: Bool = true

    init(
        liveActivityManager: LiveActivityManager?,
        alarmStore: AlarmStore,
        alarmKitService: (any AlarmKitServiceProtocol)? = nil
    ) {
        _viewModel = State(initialValue: SettingsViewModel(
            liveActivityManager: liveActivityManager,
            alarmStore: alarmStore,
            alarmKitService: alarmKitService
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PGradientBackground()

                Form {
                    // MARK: Live Activity 섹션
                    Section {
                        Toggle(isOn: $liveActivityToggle) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("잠금화면 위젯")
                                    .font(.body)
                                    .foregroundStyle(Color.pTextPrimary)
                                Text("잠금화면에 다음 알람 정보를 표시합니다")
                                    .font(.caption)
                                    .foregroundStyle(Color.pTextTertiary)
                            }
                        }
                        .tint(Color.pAccentPrimary)
                        .accessibilityLabel("잠금화면 위젯")
                        .accessibilityHint("Live Activity를 통해 잠금화면에 다음 알람 정보를 표시합니다")
                        .frame(minHeight: 44)
                        .onChange(of: liveActivityToggle) { _, newValue in
                            Task {
                                await viewModel.setLiveActivityEnabled(newValue)
                            }
                        }
                    } header: {
                        Text("Live Activity")
                            .font(.caption)
                            .foregroundStyle(Color.pTextTertiary)
                    }
                    .listRowBackground(Color.pGlassFill)

                    // MARK: 권한 섹션
                    Section {
                        HStack {
                            Text("AlarmKit 권한")
                                .font(.body)
                                .foregroundStyle(Color.pTextPrimary)
                            Spacer()
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(Color.pAccentPrimary)
                            } else {
                                Text(viewModel.alarmKitAuthStatus)
                                    .font(.body)
                                    .foregroundStyle(Color.pTextSecondary)
                            }
                        }
                        .frame(minHeight: 44)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("AlarmKit 권한: \(viewModel.alarmKitAuthStatus)")
                    } header: {
                        Text("권한")
                            .font(.caption)
                            .foregroundStyle(Color.pTextTertiary)
                    }
                    .listRowBackground(Color.pGlassFill)

                    // MARK: 피드백/문의 섹션
                    Section {
                        Link(destination: URL(string: "mailto:rlaskgns0212@naver.com?subject=BetterAlarm%20피드백")!) {
                            HStack {
                                Text("피드백 보내기")
                                    .font(.body)
                                    .foregroundStyle(Color.pTextPrimary)
                                Spacer()
                                Image(systemName: "envelope")
                                    .foregroundStyle(Color.pAccentPrimary)
                            }
                        }
                        .frame(minHeight: 44)
                        .accessibilityLabel("피드백 보내기")
                        .accessibilityHint("이메일로 피드백을 보냅니다")
                    } header: {
                        Text("피드백/문의")
                            .font(.caption)
                            .foregroundStyle(Color.pTextTertiary)
                    }
                    .listRowBackground(Color.pGlassFill)

                    // MARK: 앱 정보 섹션
                    Section {
                        HStack {
                            Text("버전")
                                .font(.body)
                                .foregroundStyle(Color.pTextPrimary)
                            Spacer()
                            Text("\(viewModel.appVersion) (\(viewModel.buildNumber))")
                                .font(.body)
                                .foregroundStyle(Color.pTextSecondary)
                        }
                        .frame(minHeight: 44)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("앱 버전 \(viewModel.appVersion), 빌드 \(viewModel.buildNumber)")
                    } header: {
                        Text("앱 정보")
                            .font(.caption)
                            .foregroundStyle(Color.pTextTertiary)
                    }
                    .listRowBackground(Color.pGlassFill)
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task {
            await viewModel.loadSettings()
            liveActivityToggle = viewModel.isLiveActivityEnabled
        }
    }
}
