font_filter_source = files('Dialogs' / 'FontFilter.vala')
font_dialog_source = files('Dialogs' / 'FontDialog.vala')
word_wrap_controller_source = files('Widgets' / 'WordWrapController.vala')
text_file_decoder_source = files('TextFileDecoder.vala')
file_open_policy_source = files('FileOpenPolicy.vala')
text_file_probe_source = files('TextFileProbe.vala')
recovery_snapshot_source = files('RecoverySnapshot.vala')
recovery_store_source = files('RecoveryStore.vala')

valapad_files = files(
    'Application.vala',
    'MainWindow.vala',
    'AutosaveController.vala',
    'Dialogs' / 'RecoveryDialog.vala',
    'Dialogs' / 'GoToDialog.vala',
    'Widgets' / 'FindBar.vala',
)

config_file = configure_file(
    input: 'config.vala.in',
    output: 'config.vala',
    configuration: conf_data,
)

executable(
    meson.project_name(),
    valapad_files,
    font_filter_source,
    font_dialog_source,
    word_wrap_controller_source,
    text_file_decoder_source,
    file_open_policy_source,
    text_file_probe_source,
    recovery_snapshot_source,
    recovery_store_source,
    config_file,
    dependencies: dependencies,
    install: true,
)
