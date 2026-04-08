import SwiftUI
import PersonalColorDesignSystem

// MARK: - SettingsView

/// 설정 화면. Form 기반 UI로 Live Activity 토글, AlarmKit 권한 상태, 앱 정보를 표시.
/// MVVM: View는 UI 선언만. 비즈니스 로직은 SettingsViewModel에 위임.
struct SettingsView: View {
    @State private var viewModel: SettingsViewModel

    init(liveActivityManager: LiveActivityManager?, alarmStore: AlarmStore) {
        _viewModel = State(initialValue: SettingsViewModel(
            liveActivityManager: liveActivityManager,
            alarmStore: alarmStore
        ))
    }

    var body: some View {
        ZStack {
            GradientBackground()
                .ignoresSafeArea()

            NavigationStack {
                Form {
                    // MARK: Live Activity 섹션
                    if #available(iOS 16.2, *) {
                        Section {
                            Toggle(isOn: $viewModel.isLiveActivityEnabled) {
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
                        } header: {
                            Text("Live Activity")
                                .font(.caption)
                                .foregroundStyle(Color.pTextTertiary)
                        }
                        .listRowBackground(Color.pGlassFill)
                    }

                    // MARK: 권한 섹션
                    Section {
                        HStack {
                            Text("AlarmKit 권한")
                                .font(.body)
                                .foregroundStyle(Color.pTextPrimary)
                            Spacer()
                            Text(viewModel.alarmKitAuthStatus)
                                .font(.body)
                                .foregroundStyle(Color.pTextSecondary)
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
                .navigationTitle("설정")
                .navigationBarTitleDisplayMode(.large)
            }
        }
        .task {
            await viewModel.loadSettings()
        }
    }
}
