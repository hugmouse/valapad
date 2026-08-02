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

run_target(
    'dogtail-tests',
    command: [
        find_program('dogtail/run-tests.sh'),
        meson.project_build_root() / 'src' / meson.project_name(),
    ],
    depends: valapad_executable,
)
