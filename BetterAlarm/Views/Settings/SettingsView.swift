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
                    Text("settings_title")
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
                            Text("settings_section_theme")
                                .font(.caption)
                                .foregroundStyle(Color.pTextTertiary)
                        }
                        .listRowBackground(Color.pGlassFill)
                    }

                    // MARK: 알림 권한 섹션
                    Section {
                        // 알림 권한 행
                        HStack {
                            Text("settings_notification_permission")
                                .font(.body)
                                .foregroundStyle(Color.pTextPrimary)
                            Spacer()
                            Text(viewModel.notificationAuthStatus)
                                .font(.body)
                                .foregroundStyle(viewModel.notificationAuthStatus == String(localized: "settings_permission_authorized") ? Color.pSuccess : Color.pWarning)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Button("settings_open_app_settings") {
                                openAppSettings()
                            }
                            .font(.caption)
                            .foregroundStyle(theme.accentPrimary)
                            .padding(.leading, 8)
                        }
                        .frame(minHeight: 44)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(Text("settings_notification_permission_a11y_format \(viewModel.notificationAuthStatus)"))

                        // AlarmKit 권한 행
                        HStack {
                            Text("settings_alarmkit_permission")
                                .font(.body)
                                .foregroundStyle(Color.pTextPrimary)
                            Spacer()
                            Text(viewModel.alarmKitAuthStatus)
                                .font(.body)
                                .foregroundStyle(viewModel.alarmKitAuthStatus == String(localized: "settings_permission_authorized") ? Color.pSuccess : Color.pTextSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            if viewModel.alarmKitAuthStatus != String(localized: "settings_requires_ios26") {
                                Button("settings_open_app_settings") {
                                    openAppSettings()
                                }
                                .font(.caption)
                                .foregroundStyle(theme.accentPrimary)
                                .padding(.leading, 8)
                            }
                        }
                        .frame(minHeight: 44)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(Text("settings_alarmkit_permission_a11y_format \(viewModel.alarmKitAuthStatus)"))
                    } header: {
                        Text("settings_section_permission")
                            .font(.caption)
                            .foregroundStyle(Color.pTextTertiary)
                    }
                    .listRowBackground(Color.pGlassFill)

                    // MARK: 잠금화면 위젯 섹션 (토글 + 권한 통합)
                    Section {
                        PToggle(String(localized: "settings_lock_widget_label"), isOn: $liveActivityToggle, icon: "lock.iphone")
                            .accessibilityLabel(Text("settings_lock_widget_label"))
                            .accessibilityHint(Text("settings_lock_widget_a11y_hint"))
                            .frame(minHeight: 44)
                            .onChange(of: liveActivityToggle) { _, newValue in
                                Task {
                                    await viewModel.setLiveActivityEnabled(newValue)
                                }
                            }

                        // 잠금화면 위젯 권한 행 — VStack 분리 (영어 라벨 잘림 방지, SPEC §7.2D)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("settings_lock_widget_permission")
                                .font(.body)
                                .foregroundStyle(Color.pTextPrimary)
                            HStack {
                                Text(viewModel.lockScreenWidgetStatus)
                                    .font(.caption)
                                    .foregroundStyle(viewModel.lockScreenWidgetStatus == String(localized: "settings_permission_authorized") ? Color.pSuccess : Color.pTextSecondary)
                                Spacer()
                                if viewModel.lockScreenWidgetStatus != String(localized: "settings_requires_ios17") {
                                    Button("settings_open_app_settings") {
                                        openAppSettings()
                                    }
                                    .font(.caption)
                                    .foregroundStyle(theme.accentPrimary)
                                }
                            }
                        }
                        .frame(minHeight: 44)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(Text("settings_lock_widget_permission_a11y_format \(viewModel.lockScreenWidgetStatus)"))
                    } header: {
                        Text("settings_section_lock_widget")
                            .font(.caption)
                            .foregroundStyle(Color.pTextTertiary)
                    }
                    .listRowBackground(Color.pGlassFill)

                    // MARK: 피드백/문의 섹션
                    Section {
                        let subject = String(localized: "settings_feedback_email_subject")
                            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "BetterAlarm%20Feedback"
                        Link(destination: URL(string: "mailto:rlaskgns0212@naver.com?subject=\(subject)")!) {
                            HStack {
                                Text("settings_feedback_button")
                                    .font(.body)
                                    .foregroundStyle(Color.pTextPrimary)
                                Spacer()
                                Image(systemName: "envelope")
                                    .foregroundStyle(theme.accentPrimary)
                            }
                        }
                        .frame(minHeight: 44)
                        .accessibilityLabel(Text("settings_feedback_button"))
                        .accessibilityHint(Text("settings_feedback_a11y_hint"))
                    } header: {
                        Text("settings_section_feedback")
                            .font(.caption)
                            .foregroundStyle(Color.pTextTertiary)
                    }
                    .listRowBackground(Color.pGlassFill)

                    // MARK: 앱 정보 섹션
                    Section {
                        HStack {
                            Text("settings_version_label")
                                .font(.body)
                                .foregroundStyle(Color.pTextPrimary)
                            Spacer()
                            Text("\(viewModel.appVersion) (\(viewModel.buildNumber))")
                                .font(.body)
                                .foregroundStyle(Color.pTextSecondary)
                        }
                        .frame(minHeight: 44)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(Text("settings_version_a11y_format \(viewModel.appVersion) \(viewModel.buildNumber)"))
                    } header: {
                        Text("settings_section_app_info")
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
            message: String(localized: "settings_loading_message")
        )
    }

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
