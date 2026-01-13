import UIKit
import AVFoundation

protocol SoundPickerDelegate: AnyObject {
    func soundPicker(_ picker: SoundPickerViewController, didSelectSound sound: AlarmSound)
}

struct AlarmSound: Equatable {
    let id: String
    let name: String
    let fileName: String?  // nil for system sounds
    let systemSoundID: SystemSoundID?

    static let availableSounds: [AlarmSound] = [
        AlarmSound(id: "default", name: "기본", fileName: nil, systemSoundID: 1005),
        AlarmSound(id: "alarm", name: "알람", fileName: nil, systemSoundID: 1304),
        AlarmSound(id: "beacon", name: "비콘", fileName: nil, systemSoundID: 1306),
        AlarmSound(id: "bulletin", name: "게시판", fileName: nil, systemSoundID: 1307),
        AlarmSound(id: "chime", name: "차임", fileName: nil, systemSoundID: 1308),
        AlarmSound(id: "circuit", name: "서킷", fileName: nil, systemSoundID: 1309),
        AlarmSound(id: "constellation", name: "별자리", fileName: nil, systemSoundID: 1310),
        AlarmSound(id: "radar", name: "레이더", fileName: nil, systemSoundID: 1311),
        AlarmSound(id: "signal", name: "신호", fileName: nil, systemSoundID: 1312),
        AlarmSound(id: "silk", name: "실크", fileName: nil, systemSoundID: 1313),
        AlarmSound(id: "bell", name: "벨소리", fileName: nil, systemSoundID: 1000),
        AlarmSound(id: "horn", name: "경적", fileName: nil, systemSoundID: 1033),
        AlarmSound(id: "electronic", name: "전자음", fileName: nil, systemSoundID: 1154)
    ]

    static func sound(forId id: String) -> AlarmSound {
        return availableSounds.first { $0.id == id } ?? availableSounds[0]
    }
}

class SoundPickerViewController: UIViewController {

    // MARK: - Properties

    weak var delegate: SoundPickerDelegate?
    private var selectedSound: AlarmSound
    private var audioPlayer: AVAudioPlayer?

    // MARK: - UI Components

    private let headerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
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
        table.register(UITableViewCell.self, forCellReuseIdentifier: "SoundCell")
        return table
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
        stopSound()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .backgroundTop

        view.addSubview(headerView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(doneButton)
        view.addSubview(tableView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 56),

            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),

            doneButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            doneButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),

            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - Actions

    @objc private func doneTapped() {
        UIView.hapticFeedback(style: .light)
        stopSound()
        delegate?.soundPicker(self, didSelectSound: selectedSound)
        dismiss(animated: true)
    }

    // MARK: - Sound Playback

    private func playSound(_ sound: AlarmSound) {
        stopSound()

        if let systemSoundID = sound.systemSoundID {
            AudioServicesPlaySystemSound(systemSoundID)
        }
    }

    private func stopSound() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
}

// MARK: - UITableViewDataSource

extension SoundPickerViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return AlarmSound.availableSounds.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SoundCell", for: indexPath)
        let sound = AlarmSound.availableSounds[indexPath.row]

        var config = cell.defaultContentConfiguration()
        config.text = sound.name
        config.textProperties.color = .textPrimary

        cell.contentConfiguration = config
        cell.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        cell.accessoryType = sound == selectedSound ? .checkmark : .none
        cell.tintColor = .accentPrimary

        return cell
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
