#!/bin/bash
me="${0}"
me_path=$(dirname $(realpath ${me}))
out_file="${me_path}/bin/container-manager"
[[ ! -d "${me_path}/bin" ]] && mkdir "${me_path}/bin"
echo "Search source classes ..."
src_list="$(ls ${me_path}/vala/*.vala)"
echo "Source classes:"
echo "${src_list}"
echo
echo "Build ..."
echo
valac --pkg posix --pkg gtk+-3.0 --pkg json-glib-1.0 -o ${out_file} ${src_list}
[[ -f "${out_file}" ]] && echo "Build successfully" || exit 1
exit 0
