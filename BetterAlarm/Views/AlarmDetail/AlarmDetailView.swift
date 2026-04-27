import SwiftUI
import PersonalColorDesignSystem

// MARK: - AlarmDetailView

/// 알람 생성/편집 화면.
/// - AlarmMode 토글: iOS 26 미만이면 PersonalColorDesignSystem 토스트 표시
/// - alarmKit 모드일 때 조용한 알람 토글 disabled
struct AlarmDetailView: View {
    @State private var viewModel: AlarmDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pThemeColors) private var theme
    private let onSaved: () -> Void
    private let onDeleted: (() -> Void)?

    init(store: AlarmStore, editingAlarm: Alarm? = nil, onSaved: @escaping () -> Void, onDeleted: (() -> Void)? = nil) {
        _viewModel = State(initialValue: AlarmDetailViewModel(store: store, editingAlarm: editingAlarm))
        self.onSaved = onSaved
        self.onDeleted = onDeleted
    }

    var body: some View {
        @Bindable var vm = viewModel
        NavigationStack {
            ZStack {
                PGradientBackground()

                Form {
                    // MARK: 시간 선택
                    Section {
                        timePicker
                    } header: {
                        Text("alarm_detail_section_time")
                            .font(.caption)
                            .foregroundStyle(Color.pTextTertiary)
                    }
                    .listRowBackground(Color.pGlassFill)

                    // MARK: 기본 설정
                    Section {
                        // 제목
                        TextField("alarm_detail_title_placeholder", text: $vm.title)
                            .foregroundStyle(Color.pTextPrimary)

                        // 반복 스케줄
                        scheduleSection
                    } header: {
                        Text("alarm_detail_section_basic")
                            .font(.caption)
                            .foregroundStyle(Color.pTextTertiary)
                    }
                    .listRowBackground(Color.pGlassFill)

                    // MARK: 알람 모드
                    Section {
                        alarmModeToggle
                    } header: {
                        Text("alarm_detail_section_mode")
                            .font(.caption)
                            .foregroundStyle(Color.pTextTertiary)
                    } footer: {
                        Text(viewModel.alarmMode == .alarmKit
                             ? "alarm_detail_alarmkit_footer_on"
                             : "alarm_detail_alarmkit_footer_off")
                            .font(.caption)
                            .foregroundStyle(Color.pTextTertiary)
                    }
                    .listRowBackground(Color.pGlassFill)

                    // MARK: 조용한 알람
                    Section {
                        silentAlarmToggle
                    } header: {
                        Text("alarm_detail_section_sound_output")
                            .font(.caption)
                            .foregroundStyle(Color.pTextTertiary)
                    } footer: {
                        if let warning = viewModel.earphoneWarning {
                            Text(warning)
                                .font(.caption)
                                .foregroundStyle(Color.pWarning)
                        } else if viewModel.alarmMode == .alarmKit {
                            Text("alarm_detail_silent_footer_alarmkit")
                                .font(.caption)
                                .foregroundStyle(Color.pTextTertiary)
                        } else {
                            Text("alarm_detail_silent_footer_default")
                                .font(.caption)
                                .foregroundStyle(Color.pTextTertiary)
                        }
                    }
                    .listRowBackground(Color.pGlassFill)

                    // MARK: 사운드
                    Section {
                        HStack {
                            Text("alarm_detail_section_sound")
                                .foregroundStyle(Color.pTextPrimary)
                            Spacer()
                            Text(viewModel.soundName == "default"
                                 ? String(localized: "alarm_detail_sound_default")
                                 : viewModel.soundName)
                                .foregroundStyle(Color.pTextSecondary)
                        }
                    } header: {
                        Text("alarm_detail_section_sound")
                            .font(.caption)
                            .foregroundStyle(Color.pTextTertiary)
                    }
                    .listRowBackground(Color.pGlassFill)

                    // MARK: 삭제 (편집 모드만)
                    if viewModel.isEditing {
                        Section {
                            Button(role: .destructive) {
                                Task {
                                    await viewModel.deleteAlarm()
                                    onDeleted?()
                                    dismiss()
                                }
                            } label: {
                                HStack {
                                    Spacer()
                                    Text("alarm_detail_delete_button")
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(Color.pWarning)
                                    Spacer()
                                }
                            }
                            .disabled(viewModel.isDeleting)
                            .frame(minHeight: 44)
                        }
                        .listRowBackground(Color.pGlassFill)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text(viewModel.isEditing ? "alarm_detail_title_edit" : "alarm_detail_title_new")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.pTextPrimary)
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("alarm_detail_cancel_button") {
                            dismiss()
                        }
                        .foregroundStyle(Color.pTextSecondary)
                        .frame(minWidth: 44, minHeight: 44)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            Task {
                                await viewModel.save()
                                if viewModel.saveError == nil {
                                    HapticManager.notification(.success)
                                    onSaved()
                                    dismiss()
                                }
                            }
                        } label: {
                            Text("alarm_detail_save_button")
                        }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(theme.accentPrimary)
                        .disabled(viewModel.isSaving)
                        .frame(minWidth: 44, minHeight: 44)
                    }
                }
        }
        .pLoadingOverlay(
            isLoading: Binding(get: { viewModel.isSaving || viewModel.isDeleting }, set: { _ in }),
            message: viewModel.isSaving
                ? String(localized: "alarm_detail_saving")
                : String(localized: "alarm_detail_deleting")
        )
        .toast(
            isPresented: Binding(
                get: { viewModel.showAlarmKitUnavailableToast },
                set: { if !$0 { viewModel.dismissToast() } }
            ),
            message: viewModel.toastMessage,
            type: .warning
        )
        // 저장 에러 표시
        .alert(Text("alarm_detail_save_error_title"), isPresented: Binding(
            get: { viewModel.saveError != nil },
            set: { if !$0 { viewModel.clearSaveError() } }
        )) {
            Button("alarm_detail_ok_button", role: .cancel) {}
        } message: {
            if let error = viewModel.saveError {
                Text(error)
            }
        }
    }

    // MARK: - Time Picker

    @ViewBuilder
    private var timePicker: some View {
        @Bindable var vm = viewModel
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            // AM/PM 선택 (로케일 자동 반영)
            Picker("alarm_detail_picker_period_a11y", selection: $vm.isPM) {
                Text("alarm_detail_period_am").tag(false)
                Text("alarm_detail_period_pm").tag(true)
            }
            .pickerStyle(.wheel)
            .frame(width: 70)
            .clipped()
            .accessibilityLabel(Text("alarm_detail_picker_period_a11y"))

            // 시 선택 (1~12)
            Picker("alarm_detail_picker_hour_a11y", selection: $vm.displayHour) {
                ForEach(1...12, id: \.self) { h in
                    Text(String(format: NSLocalizedString("alarm_detail_hour_unit_format", comment: ""), h)).tag(h)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 80)
            .clipped()
            .accessibilityLabel(Text("alarm_detail_picker_hour_a11y"))

            // 분 선택
            Picker("alarm_detail_picker_minute_a11y", selection: $vm.minute) {
                ForEach(0..<60, id: \.self) { m in
                    Text(String(format: NSLocalizedString("alarm_detail_minute_unit_format", comment: ""), m)).tag(m)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 80)
            .clipped()
            .accessibilityLabel(Text("alarm_detail_picker_minute_a11y"))

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        .colorScheme(.dark)
    }

    // MARK: - Schedule Section

    @ViewBuilder
    private var scheduleSection: some View {
        @Bindable var vm = viewModel
        Picker("alarm_detail_repeat_a11y", selection: $vm.scheduleType) {
            ForEach(AlarmDetailViewModel.ScheduleType.allCases, id: \.self) { type in
                Text(type.displayName).tag(type)
            }
        }
        .pickerStyle(.segmented)
        .colorScheme(.dark)
        .accessibilityLabel(Text("alarm_detail_repeat_a11y"))
        .onChange(of: viewModel.scheduleType) { _, _ in
            viewModel.handleScheduleTypeChange()
        }

        if viewModel.scheduleType == .weekly {
            weekdayPicker
        }

        if viewModel.scheduleType == .specificDate {
            DatePicker(
                "alarm_detail_date_label",
                selection: $vm.specificDate,
                in: Date()...,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .colorScheme(.dark)
            .foregroundStyle(Color.pTextPrimary)
            .accessibilityLabel(Text("alarm_detail_date_a11y"))
        }
    }

    private var weekdayPicker: some View {
        HStack(spacing: 8) {
            ForEach(Weekday.allCases, id: \.self) { day in
                let isSelected = viewModel.selectedWeekdays.contains(day)
                Button {
                    if isSelected {
                        viewModel.selectedWeekdays.remove(day)
                    } else {
                        viewModel.selectedWeekdays.insert(day)
                    }
                    HapticManager.selection()
                } label: {
                    Text(day.shortName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isSelected ? .white : Color.pTextTertiary)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(isSelected ? theme.accentPrimary : Color.pGlassFill)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(isSelected
                    ? "alarm_detail_weekday_a11y_selected_format \(day.shortName)"
                    : "alarm_detail_weekday_a11y_unselected_format \(day.shortName)"))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - AlarmMode Toggle
    // UI 잘림 보강: 영어 "Ring even when app is closed"(28자)가 한 줄 안 들어갈 수 있으므로
    // HStack + lineLimit(2) fallback 패턴 적용 (SPEC §7.2B)

    private var alarmModeToggle: some View {
        HStack {
            Text("alarm_detail_alarmkit_toggle_label")
                .font(.body)
                .foregroundStyle(Color.pTextPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Toggle("", isOn: Binding(
                get: { viewModel.alarmMode == .alarmKit },
                set: { viewModel.toggleAlarmMode(wantsAlarmKit: $0) }
            ))
            .labelsHidden()
        }
        .accessibilityLabel(Text("alarm_detail_alarmkit_toggle_label"))
        .accessibilityHint(Text("alarm_detail_alarmkit_toggle_a11y_hint"))
    }

    // MARK: - Silent Alarm Toggle

    private var silentAlarmToggle: some View {
        PToggle(String(localized: "alarm_detail_silent_toggle_label"), isOn: Binding(
            get: { viewModel.isSilentAlarm },
            set: { enabled in Task { await viewModel.validateSilentAlarm(enabled: enabled) } }
        ), icon: "headphones")
        .disabled(viewModel.alarmMode == .alarmKit)
        .accessibilityLabel(Text("alarm_detail_silent_toggle_label"))
        .accessibilityHint(viewModel.alarmMode == .alarmKit
            ? Text("alarm_detail_silent_a11y_hint_alarmkit")
            : Text("alarm_detail_silent_a11y_hint_default"))
    }
}
