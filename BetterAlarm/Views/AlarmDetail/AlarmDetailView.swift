import SwiftUI
import PersonalColorDesignSystem

// MARK: - AlarmDetailView

/// 알람 생성/편집 화면.
/// - AlarmMode 토글: iOS 26 미만이면 PersonalColorDesignSystem 토스트 표시
/// - alarmKit 모드일 때 조용한 알람 토글 disabled
struct AlarmDetailView: View {
    @State private var viewModel: AlarmDetailViewModel
    @Environment(\.dismiss) private var dismiss
    private let onSaved: () -> Void

    init(store: AlarmStore, editingAlarm: Alarm? = nil, onSaved: @escaping () -> Void) {
        _viewModel = State(initialValue: AlarmDetailViewModel(store: store, editingAlarm: editingAlarm))
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PGradientBackground()

                Form {
                    // MARK: 시간 선택
                    Section {
                        timePicker
                    } header: {
                        Text("시간")
                            .font(.caption)
                            .foregroundStyle(Color.pTextTertiary)
                    }
                    .listRowBackground(Color.pGlassFill)

                    // MARK: 기본 설정
                    Section {
                        // 제목
                        HStack {
                            Text("제목")
                                .foregroundStyle(Color.pTextPrimary)
                            Spacer()
                            TextField("알람", text: $viewModel.title)
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(Color.pTextSecondary)
                        }

                        // 반복 스케줄
                        scheduleSection
                    } header: {
                        Text("기본 설정")
                            .font(.caption)
                            .foregroundStyle(Color.pTextTertiary)
                    }
                    .listRowBackground(Color.pGlassFill)

                    // MARK: 알람 모드
                    Section {
                        alarmModeToggle
                    } header: {
                        Text("알람 모드")
                            .font(.caption)
                            .foregroundStyle(Color.pTextTertiary)
                    } footer: {
                        Text(viewModel.alarmMode == .alarmKit
                             ? "앱이 꺼진 상태에서도 알람이 울립니다. (iOS 26 이상 필요)"
                             : "앱이 백그라운드 또는 포그라운드 상태에서 알람이 울립니다.")
                            .font(.caption)
                            .foregroundStyle(Color.pTextTertiary)
                    }
                    .listRowBackground(Color.pGlassFill)

                    // MARK: 조용한 알람
                    Section {
                        silentAlarmToggle
                    } header: {
                        Text("소리 출력")
                            .font(.caption)
                            .foregroundStyle(Color.pTextTertiary)
                    } footer: {
                        if let warning = viewModel.earphoneWarning {
                            Text(warning)
                                .font(.caption)
                                .foregroundStyle(Color.pWarning)
                        } else if viewModel.alarmMode == .alarmKit {
                            Text("AlarmKit 모드에서는 조용한 알람을 지원하지 않습니다.")
                                .font(.caption)
                                .foregroundStyle(Color.pTextTertiary)
                        } else {
                            Text("이어폰 연결 시 이어폰으로만 소리가 출력됩니다.")
                                .font(.caption)
                                .foregroundStyle(Color.pTextTertiary)
                        }
                    }
                    .listRowBackground(Color.pGlassFill)

                    // MARK: 사운드
                    Section {
                        HStack {
                            Text("사운드")
                                .foregroundStyle(Color.pTextPrimary)
                            Spacer()
                            Text(viewModel.soundName == "default" ? "기본" : viewModel.soundName)
                                .foregroundStyle(Color.pTextSecondary)
                        }
                    } header: {
                        Text("사운드")
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
                                    onSaved()
                                    dismiss()
                                }
                            } label: {
                                HStack {
                                    Spacer()
                                    Text("알람 삭제")
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(Color.pWarning)
                                    Spacer()
                                }
                            }
                            .frame(minHeight: 44)
                        }
                        .listRowBackground(Color.pGlassFill)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            .navigationTitle(viewModel.isEditing ? "알람 편집" : "새 알람")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("취소") {
                            dismiss()
                        }
                        .foregroundStyle(Color.pTextSecondary)
                        .frame(minWidth: 44, minHeight: 44)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("저장") {
                            Task {
                                await viewModel.save()
                                if viewModel.saveError == nil {
                                    HapticManager.notification(.success)
                                    onSaved()
                                    dismiss()
                                }
                            }
                        }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.pAccentPrimary)
                        .disabled(viewModel.isSaving)
                        .frame(minWidth: 44, minHeight: 44)
                    }
                }
        }
        .toast(
            isPresented: Binding(
                get: { viewModel.showAlarmKitUnavailableToast },
                set: { if !$0 { viewModel.dismissToast() } }
            ),
            message: viewModel.toastMessage,
            type: .warning
        )
        // 저장 에러 표시
        .alert("저장 실패", isPresented: Binding(
            get: { viewModel.saveError != nil },
            set: { if !$0 { viewModel.clearSaveError() } }
        )) {
            Button("확인", role: .cancel) {}
        } message: {
            if let error = viewModel.saveError {
                Text(error)
            }
        }
    }

    // MARK: - Time Picker

    private var timePicker: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            // 오전/오후 선택
            Picker("오전/오후", selection: $viewModel.isPM) {
                Text("오전").tag(false)
                Text("오후").tag(true)
            }
            .pickerStyle(.wheel)
            .frame(width: 70)
            .clipped()
            .accessibilityLabel("오전 오후 선택")

            // 시 선택 (1~12)
            Picker("시", selection: $viewModel.displayHour) {
                ForEach(1...12, id: \.self) { h in
                    Text("\(h)시").tag(h)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 80)
            .clipped()
            .accessibilityLabel("시 선택")

            // 분 선택
            Picker("분", selection: $viewModel.minute) {
                ForEach(0..<60, id: \.self) { m in
                    Text(String(format: "%02d분", m)).tag(m)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 80)
            .clipped()
            .accessibilityLabel("분 선택")

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        .colorScheme(.dark)
    }

    // MARK: - Schedule Section

    @ViewBuilder
    private var scheduleSection: some View {
        Picker("반복", selection: $viewModel.scheduleType) {
            ForEach(AlarmDetailViewModel.ScheduleType.allCases, id: \.self) { type in
                Text(type.rawValue).tag(type)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("알람 반복 유형 선택")

        if viewModel.scheduleType == .weekly {
            weekdayPicker
        }

        if viewModel.scheduleType == .specificDate {
            DatePicker(
                "날짜",
                selection: $viewModel.specificDate,
                in: Date()...,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .foregroundStyle(Color.pTextPrimary)
            .accessibilityLabel("특정 날짜 선택")
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
                                .fill(isSelected ? Color.pAccentPrimary : Color.pGlassFill)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(day.shortName) \(isSelected ? "선택됨" : "선택 안됨")")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - AlarmMode Toggle

    private var alarmModeToggle: some View {
        Toggle(isOn: Binding(
            get: { viewModel.alarmMode == .alarmKit },
            set: { wantsAlarmKit in
                viewModel.toggleAlarmMode(wantsAlarmKit: wantsAlarmKit)
            }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text("앱이 꺼진 상태에서도 알람 받기")
                    .font(.body)
                    .foregroundStyle(Color.pTextPrimary)
                Text("iOS 26 이상에서만 사용 가능")
                    .font(.caption)
                    .foregroundStyle(Color.pTextTertiary)
            }
        }
        .tint(Color.pAccentPrimary)
        .accessibilityLabel("앱이 꺼진 상태에서도 알람 받기")
        .accessibilityHint("iOS 26 이상에서만 사용할 수 있습니다")
    }

    // MARK: - Silent Alarm Toggle

    private var silentAlarmToggle: some View {
        Toggle(isOn: Binding(
            get: { viewModel.isSilentAlarm },
            set: { enabled in
                Task { await viewModel.validateSilentAlarm(enabled: enabled) }
            }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                Text("조용한 알람")
                    .font(.body)
                    .foregroundStyle(
                        viewModel.alarmMode == .alarmKit
                            ? Color.pTextTertiary
                            : Color.pTextPrimary
                    )
                Text("이어폰 연결 시 이어폰으로만 재생")
                    .font(.caption)
                    .foregroundStyle(Color.pTextTertiary)
            }
        }
        .disabled(viewModel.alarmMode == .alarmKit)
        .tint(Color.pAccentSecondary)
        .accessibilityLabel("조용한 알람")
        .accessibilityHint(
            viewModel.alarmMode == .alarmKit
                ? "AlarmKit 모드에서는 사용할 수 없습니다"
                : "이어폰 연결 시 이어폰으로만 소리가 출력됩니다"
        )
    }
}

