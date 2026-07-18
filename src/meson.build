font_filter_source = files('Dialogs' / 'FontFilter.vala')
font_dialog_source = files('Dialogs' / 'FontDialog.vala')
word_wrap_controller_source = files('Widgets' / 'WordWrapController.vala')
text_file_decoder_source = files('TextFileDecoder.vala')

valapad_files = files(
    'Application.vala',
    'MainWindow.vala',
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
    config_file,
    dependencies: dependencies,
    install: true,
)
