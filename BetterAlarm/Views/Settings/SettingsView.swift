import SwiftUI
import PersonalColorDesignSystem

// MARK: - SettingsView

/// 설정 화면. 커스텀 헤더 + Form 기반 UI.
struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    @State private var liveActivityToggle: Bool = true

    init(
        liveActivityManager: LiveActivityManager?,
        alarmStore: AlarmStore,
        alarmKitService: (any AlarmKitServiceProtocol)? = nil,
        themeManager: AppThemeManager? = nil
    ) {
        _viewModel = State(initialValue: SettingsViewModel(
            liveActivityManager: liveActivityManager,
            alarmStore: alarmStore,
            alarmKitService: alarmKitService,
            themeManager: themeManager
        ))
    }

    var body: some View {
        ZStack {
            PGradientBackground()

            VStack(spacing: 0) {
                // 고정 헤더
                HStack {
                    Text("설정")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Color.pTextPrimary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)

                Form {
                    // MARK: 테마 섹션
                    if let themeManager = viewModel.themeManager {
                        Section {
                            HStack(spacing: 12) {
                                ForEach(PTheme.allCases) { theme in
                                    Button {
                                        themeManager.setTheme(theme)
                                    } label: {
                                        VStack(spacing: 4) {
                                            Circle()
                                                .fill(theme.colors.accentPrimary)
                                                .frame(width: 36, height: 36)
                                                .overlay(
                                                    Circle()
                                                        .stroke(themeManager.currentTheme == theme ? Color.pTextPrimary : Color.clear, lineWidth: 2)
                                                )
                                            Text(theme.displayName)
                                                .font(.caption2)
                                                .foregroundStyle(Color.pTextSecondary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        } header: {
                            Text("테마")
                                .font(.caption)
                                .foregroundStyle(Color.pTextTertiary)
                        }
                        .listRowBackground(Color.pGlassFill)
                    }

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
                        // 알림 권한 행
                        HStack {
                            Text("알림 권한")
                                .font(.body)
                                .foregroundStyle(Color.pTextPrimary)
                            Spacer()
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(Color.pAccentPrimary)
                            } else {
                                Text(viewModel.notificationAuthStatus)
                                    .font(.body)
                                    .foregroundStyle(viewModel.notificationAuthStatus == "허용됨" ? Color.pSuccess : Color.pWarning)
                                Button("설정 열기") {
                                    openAppSettings()
                                }
                                .font(.caption)
                                .foregroundStyle(Color.pAccentPrimary)
                                .padding(.leading, 8)
                            }
                        }
                        .frame(minHeight: 44)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("알림 권한: \(viewModel.notificationAuthStatus)")

                        // AlarmKit 권한 행
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
                                    .foregroundStyle(viewModel.alarmKitAuthStatus == "허용됨" ? Color.pSuccess : Color.pTextSecondary)
                                if viewModel.alarmKitAuthStatus != "iOS 26 이상 필요" {
                                    Button("설정 열기") {
                                        openAppSettings()
                                    }
                                    .font(.caption)
                                    .foregroundStyle(Color.pAccentPrimary)
                                    .padding(.leading, 8)
                                }
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
        }
        .toolbarBackground(Color.pTabBarBackground, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .task {
            await viewModel.loadSettings()
            liveActivityToggle = viewModel.isLiveActivityEnabled
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task { await viewModel.refreshPermissions() }
        }
    }

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
