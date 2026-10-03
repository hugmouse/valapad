project(
    'dev.mysh.valapad',
    'vala',
    'c',
    version: '1.2.0',
    meson_version: '>= 0.64.0',
)

gettext_name = meson.project_name()
gnome = import('gnome')
i18n = import('i18n')

app_id = 'dev.mysh.valapad'

add_project_arguments(
    [
        '--target-glib=2.72',
        '--enable-experimental',
        '--define=GETTEXT_PACKAGE="@0@"'.format(gettext_name),
    ],
    language: 'vala',
)

if host_machine.system() == 'linux'
    add_project_arguments('--define=LINUX', language: 'vala')
elif host_machine.system() == 'darwin'
    add_project_arguments('--define=MACOS', language: 'vala')
endif

add_project_arguments(
    '-Wall',
    '-Wextra',
    '-D_GNU_SOURCE',
    '-DGETTEXT_PACKAGE="@0@"'.format(gettext_name),
    language: 'c',
)

conf_data = configuration_data()
conf_data.set('GETTEXT_PACKAGE', gettext_name)
conf_data.set('LOCALEDIR', get_option('prefix') / get_option('localedir'))
conf_data.set('GSETTINGS_SCHEMA_DIR', meson.project_build_root() / 'data')
conf_data.set('PROJECT_NAME', app_id)
conf_data.set('VERSION', meson.project_version())

dependencies = [
    dependency('gtk4', version: '>= 4.14'),
    dependency('granite-7', version: '>= 7.0.0'),
    dependency('glib-2.0'),
    dependency('pango'),
    dependency('pangocairo'),
]

subdir('data')
subdir('src')
subdir('tests')
subdir('po')

gnome.post_install(
    glib_compile_schemas: true,
    gtk_update_icon_cache: true,
    update_desktop_database: true,
)
