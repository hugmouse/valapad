font_filter_source = files('Dialogs' / 'FontFilter.vala')
font_dialog_source = files('Dialogs' / 'FontDialog.vala')
word_wrap_controller_source = files('Widgets' / 'WordWrapController.vala')
text_file_decoder_source = files('TextFileDecoder.vala')
text_file_probe_source = files('TextFileProbe.vala')
document_source = files('Document.vala')
font_css_source = files('FontCss.vala')
recovery_snapshot_source = files('RecoverySnapshot.vala')
recovery_store_source = files('RecoveryStore.vala')
autosave_controller_source = files('AutosaveController.vala')
recovery_workflow_source = files('RecoveryWorkflow.vala')
print_layout_source = files('PrintLayout.vala')
css_source = files('CSS.vala')
style_resources = gnome.compile_resources(
    'valapad-resources',
    '../data/dev.mysh.valapad.gresource.xml',
    source_dir: '../data',
    c_name: 'valapad',
)

valapad_files = files(
    'Dialogs' / 'RecoveryDialog.vala',
    'Dialogs' / 'GoToDialog.vala',
    'Widgets' / 'FindBar.vala',
    'Application.vala',
    'EscapeController.vala',
    'MainWindow.vala',
)

config_file = configure_file(
    input: 'config.vala.in',
    output: 'config.vala',
    configuration: conf_data,
)

valapad_executable = executable(
    meson.project_name(),
    valapad_files,
    css_source,
    style_resources,
    font_filter_source,
    font_dialog_source,
    word_wrap_controller_source,
    text_file_decoder_source,
    text_file_probe_source,
    document_source,
    font_css_source,
    recovery_snapshot_source,
    recovery_store_source,
    autosave_controller_source,
    recovery_workflow_source,
    print_layout_source,
    config_file,
    dependencies: dependencies,
    install: true,
)
