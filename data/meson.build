# Desktop file
# Keep metadata translations in a separate catalog, as AppCenter does.
i18n.merge_file(
  input: app_id + '.desktop.in',
  output: app_id + '.desktop',
  po_dir: meson.project_source_root() / 'po' / 'extra',
  type: 'desktop',
  install: true,
  install_dir: get_option('datadir') / 'applications',
)

# Metainfo
metainfo = i18n.merge_file(
  input: app_id + '.metainfo.xml.in',
  output: app_id + '.metainfo.xml',
  po_dir: meson.project_source_root() / 'po' / 'extra',
  type: 'xml',
  install: true,
  install_dir: get_option('datadir') / 'metainfo',
)

ascli = find_program('appstreamcli', required: false)
if ascli.found()
  test(
    'validate metainfo file',
    ascli,
    args: ['validate', '--no-net', '--pedantic', metainfo],
  )
endif

# GSchema
gschema_file = files(app_id + '.gschema.xml')
gnome.compile_schemas(
  depend_files: gschema_file,
  build_by_default: true,
)
install_data(
  gschema_file,
  install_dir: join_paths(get_option('datadir'), 'glib-2.0', 'schemas')
)

# TODO: Create 6 slightly different SVGs
icon_sizes = ['16', '24', '32', '48', '64', '128']

foreach size : icon_sizes
  install_data(
    'icons/valapad.svg',
    install_dir: get_option('datadir') / 'icons' / 'hicolor' / size + 'x' + size / 'apps',
    rename: app_id + '.svg'
  )
  install_data(
    'icons/valapad.svg',
    install_dir: get_option('datadir') / 'icons' / 'hicolor' / size + 'x' + size + '@2' / 'apps',
    rename: app_id + '.svg'
  )
endforeach

install_data(
  'icons/valapad.svg',
  install_dir: get_option('datadir') / 'icons' / 'hicolor' / 'scalable' / 'apps',
  rename: app_id + '.svg'
)

install_data(
  'icons/symbolic.svg',
  install_dir: get_option('datadir') / 'icons' / 'hicolor' / 'symbolic' / 'apps',
  rename: app_id + '-symbolic.svg'
)
