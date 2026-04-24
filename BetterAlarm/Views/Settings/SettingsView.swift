import SwiftUI
import PersonalColorDesignSystem

// MARK: - SettingsView

/// 설정 화면. 커스텀 헤더 + Form 기반 UI.
struct SettingsView: View {
    @State private var viewModel: SettingsViewModel
    @State private var liveActivityToggle: Bool = true
    @Environment(\.pThemeColors) private var theme

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
                .padding(.top, 16)

                Form {
                    // MARK: 테마 섹션
                    if let themeManager = viewModel.themeManager {
                        Section {
                            HStack(spacing: 12) {
                                ForEach(PTheme.allCases) { theme in
                                    Button {
                                        viewModel.selectThemeByName(theme.rawValue)
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

                    // MARK: 알림 권한 섹션
                    Section {
                        // 알림 권한 행
                        HStack {
                            Text("알림 권한")
                                .font(.body)
                                .foregroundStyle(Color.pTextPrimary)
                            Spacer()
                            Text(viewModel.notificationAuthStatus)
                                .font(.body)
                                .foregroundStyle(viewModel.notificationAuthStatus == "허용됨" ? Color.pSuccess : Color.pWarning)
                            Button("설정 열기") {
                                openAppSettings()
                            }
                            .font(.caption)
                            .foregroundStyle(theme.accentPrimary)
                            .padding(.leading, 8)
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
                            Text(viewModel.alarmKitAuthStatus)
                                .font(.body)
                                .foregroundStyle(viewModel.alarmKitAuthStatus == "허용됨" ? Color.pSuccess : Color.pTextSecondary)
                            if viewModel.alarmKitAuthStatus != "iOS 26 이상 필요" {
                                Button("설정 열기") {
                                    openAppSettings()
                                }
                                .font(.caption)
                                .foregroundStyle(theme.accentPrimary)
                                .padding(.leading, 8)
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

                    // MARK: 잠금화면 위젯 섹션 (토글 + 권한 통합)
                    Section {
                        PToggle("잠금화면 위젯", isOn: $liveActivityToggle, icon: "lock.iphone")
                            .accessibilityLabel("잠금화면 위젯")
                            .accessibilityHint("Live Activity를 통해 잠금화면에 다음 알람 정보를 표시합니다")
                            .frame(minHeight: 44)
                            .onChange(of: liveActivityToggle) { _, newValue in
                                Task {
                                    await viewModel.setLiveActivityEnabled(newValue)
                                }
                            }

                        // 잠금화면 위젯 권한 행
                        HStack {
                            Text("잠금화면 위젯 권한")
                                .font(.body)
                                .foregroundStyle(Color.pTextPrimary)
                            Spacer()
                            Text(viewModel.lockScreenWidgetStatus)
                                .font(.body)
                                .foregroundStyle(viewModel.lockScreenWidgetStatus == "허용됨" ? Color.pSuccess : Color.pTextSecondary)
                            if viewModel.lockScreenWidgetStatus != "iOS 17 이상 필요" {
                                Button("설정 열기") {
                                    openAppSettings()
                                }
                                .font(.caption)
                                .foregroundStyle(theme.accentPrimary)
                                .padding(.leading, 8)
                            }
                        }
                        .frame(minHeight: 44)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("잠금화면 위젯 권한: \(viewModel.lockScreenWidgetStatus)")
                    } header: {
                        Text("잠금화면 위젯")
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
                                    .foregroundStyle(theme.accentPrimary)
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
        .toast(
            isPresented: Binding(
                get: { viewModel.showThemeToast },
                set: { if !$0 { viewModel.dismissThemeToast() } }
            ),
            message: viewModel.themeToastMessage,
            type: .success
        )
        // toolbarBackground 제거: SwiftUI 기본 탭바 렌더링에 위임
        .task {
            await viewModel.loadSettings()
            liveActivityToggle = viewModel.isLiveActivityEnabled
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task { await viewModel.refreshPermissions() }
        }
        .pLoadingOverlay(
            isLoading: Binding(get: { viewModel.isLoading }, set: { _ in }),
            message: "권한 확인 중..."
        )
    }

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
