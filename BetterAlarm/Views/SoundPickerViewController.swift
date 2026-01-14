import UIKit
import AVFoundation

protocol SoundPickerDelegate: AnyObject {
    func soundPicker(_ picker: SoundPickerViewController, didSelectSound sound: AlarmSound)
}

struct AlarmSound: Equatable, Codable {
    let id: String
    let name: String
    let systemSoundID: UInt32

    // SystemSoundID 변환
    var soundID: SystemSoundID {
        return SystemSoundID(systemSoundID)
    }

    // 사용 가능한 알람 사운드 목록
    static let availableSounds: [AlarmSound] = [
        AlarmSound(id: "default", name: "기본 알람", systemSoundID: 1005),
        AlarmSound(id: "tritone", name: "트라이톤", systemSoundID: 1007),
        AlarmSound(id: "alert", name: "경고음", systemSoundID: 1011),
        AlarmSound(id: "glass", name: "유리", systemSoundID: 1013),
        AlarmSound(id: "horn", name: "경적", systemSoundID: 1014),
        AlarmSound(id: "bell", name: "벨소리", systemSoundID: 1016),
        AlarmSound(id: "electronic", name: "전자음", systemSoundID: 1020),
        AlarmSound(id: "anticipate", name: "기대", systemSoundID: 1021),
        AlarmSound(id: "bloom", name: "블룸", systemSoundID: 1022),
        AlarmSound(id: "calypso", name: "칼립소", systemSoundID: 1023),
        AlarmSound(id: "chime", name: "차임", systemSoundID: 1024),
        AlarmSound(id: "complete", name: "완료", systemSoundID: 1025),
        AlarmSound(id: "fanfare", name: "팡파레", systemSoundID: 1026),
        AlarmSound(id: "ladder", name: "사다리", systemSoundID: 1027),
        AlarmSound(id: "minuet", name: "미뉴엣", systemSoundID: 1028),
        AlarmSound(id: "newsflash", name: "뉴스", systemSoundID: 1029),
        AlarmSound(id: "noir", name: "느와르", systemSoundID: 1030),
        AlarmSound(id: "sherwood", name: "셔우드", systemSoundID: 1031),
        AlarmSound(id: "spell", name: "주문", systemSoundID: 1032),
        AlarmSound(id: "suspense", name: "서스펜스", systemSoundID: 1033)
    ]

    static func sound(forId id: String) -> AlarmSound {
        return availableSounds.first { $0.id == id } ?? availableSounds[0]
    }

    // Equatable
    static func == (lhs: AlarmSound, rhs: AlarmSound) -> Bool {
        return lhs.id == rhs.id
    }
}

class SoundPickerViewController: UIViewController {

    // MARK: - Properties

    weak var delegate: SoundPickerDelegate?
    private var selectedSound: AlarmSound

    // MARK: - UI Components

    private let headerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .backgroundTop
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "알람 소리"
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .textPrimary
        return label
    }()

    private lazy var doneButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("완료", for: .normal)
        button.setTitleColor(.accentPrimary, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        return button
    }()

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.backgroundColor = .clear
        table.delegate = self
        table.dataSource = self
        table.register(SoundCell.self, forCellReuseIdentifier: SoundCell.identifier)
        table.separatorColor = UIColor.white.withAlphaComponent(0.1)
        table.separatorInset = UIEdgeInsets(top: 0, left: 56, bottom: 0, right: 0)
        return table
    }()

    private let infoLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "앱이 열려있을 때만 선택한 소리가 재생됩니다.\n백그라운드에서는 시스템 알람 소리가 사용됩니다."
        label.font = .systemFont(ofSize: 12)
        label.textColor = .textTertiary
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    // MARK: - Initialization

    init(selectedSoundId: String) {
        self.selectedSound = AlarmSound.sound(forId: selectedSoundId)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.selectedSound = AlarmSound.availableSounds[0]
        super.init(coder: coder)
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .backgroundTop

        view.addSubview(headerView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(doneButton)
        view.addSubview(tableView)
        view.addSubview(infoLabel)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 56),

            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),

            doneButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            doneButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),

            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: infoLabel.topAnchor, constant: -16),

            infoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            infoLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            infoLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    // MARK: - Actions

    @objc private func doneTapped() {
        UIView.hapticFeedback(style: .light)
        delegate?.soundPicker(self, didSelectSound: selectedSound)
        dismiss(animated: true)
    }

    // MARK: - Sound Playback (미리듣기용 - SystemSound 사용)

    private func playSound(_ sound: AlarmSound) {
        AudioServicesPlaySystemSound(sound.soundID)
    }
}

// MARK: - Sound Cell

class SoundCell: UITableViewCell {
    static let identifier = "SoundCell"

    private let playIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(systemName: "speaker.wave.2.fill")
        imageView.tintColor = .accentPrimary
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 17)
        label.textColor = .textPrimary
        return label
    }()

    private let checkmarkView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(systemName: "checkmark")
        imageView.tintColor = .accentPrimary
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = UIColor.white.withAlphaComponent(0.05)
        selectionStyle = .default

        let selectedView = UIView()
        selectedView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        selectedBackgroundView = selectedView

        contentView.addSubview(playIconView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(checkmarkView)

        NSLayoutConstraint.activate([
            playIconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            playIconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            playIconView.widthAnchor.constraint(equalToConstant: 24),
            playIconView.heightAnchor.constraint(equalToConstant: 24),

            nameLabel.leadingAnchor.constraint(equalTo: playIconView.trailingAnchor, constant: 16),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: checkmarkView.leadingAnchor, constant: -16),

            checkmarkView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            checkmarkView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkmarkView.widthAnchor.constraint(equalToConstant: 20),
            checkmarkView.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    func configure(with sound: AlarmSound, isSelected: Bool) {
        nameLabel.text = sound.name
        checkmarkView.isHidden = !isSelected

        if isSelected {
            nameLabel.textColor = .accentPrimary
            nameLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        } else {
            nameLabel.textColor = .textPrimary
            nameLabel.font = .systemFont(ofSize: 17)
        }
    }
}

// MARK: - UITableViewDataSource

extension SoundPickerViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return AlarmSound.availableSounds.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: SoundCell.identifier, for: indexPath) as? SoundCell else {
            return UITableViewCell()
        }

        let sound = AlarmSound.availableSounds[indexPath.row]
        let isSelected = sound == selectedSound
        cell.configure(with: sound, isSelected: isSelected)

        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 52
    }
}

// MARK: - UITableViewDelegate

extension SoundPickerViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let sound = AlarmSound.availableSounds[indexPath.row]
        selectedSound = sound

        UIView.hapticFeedback(style: .light)
        playSound(sound)

        tableView.reloadData()
    }
}
