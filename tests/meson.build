text_file_decoder_test = executable(
    'text-file-decoder-test',
    'TextFileDecoderTest.vala',
    text_file_decoder_source,
    dependencies: [dependency('glib-2.0'), dependency('gobject-2.0')],
)

test('text file decoder', text_file_decoder_test)

text_file_probe_test = executable(
    'text-file-probe-test',
    'TextFileProbeTest.vala',
    text_file_probe_source,
    dependencies: [dependency('glib-2.0'), dependency('gobject-2.0')],
)

test('text file probe', text_file_probe_test)

print_layout_test = executable(
    'print-layout-test',
    'PrintLayoutTest.vala',
    print_layout_source,
    dependencies: [dependency('glib-2.0'), dependency('gobject-2.0')],
)

test('print layout', print_layout_test)

recovery_workflow_test = executable(
    'recovery-workflow-test',
    'RecoveryWorkflowTest.vala',
    recovery_workflow_source,
    recovery_snapshot_source,
    dependencies: [dependency('glib-2.0'), dependency('gobject-2.0')],
)

test('recovery workflow', recovery_workflow_test)

autosave_controller_test = executable(
    'autosave-controller-test',
    'AutosaveControllerTest.vala',
    autosave_controller_source,
    recovery_store_source,
    recovery_snapshot_source,
    config_file,
    dependencies: [
        dependency('glib-2.0'),
        dependency('gobject-2.0'),
        dependency('gtk4'),
    ],
)

test('autosave controller', autosave_controller_test)

font_filter_test = executable(
    'font-filter-test',
    'FontFilterTest.vala',
    font_filter_source,
    dependencies: [dependency('glib-2.0'), dependency('gobject-2.0')],
)

test('font filter', font_filter_test)

run_target(
    'dogtail-tests',
    command: [
        find_program('dogtail/run-tests.sh'),
        meson.project_build_root() / 'src' / meson.project_name(),
    ],
    depends: valapad_executable,
)
