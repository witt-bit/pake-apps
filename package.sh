#!/usr/bin/env bash

# 构造pake的命令行参数
build_pake_options() {
    local name="$1";
    local pack_config="$2";
    local pack_dir=$(dirname "${pack_config}");
    local pack_package_icon=$(jq -r '.icon' "${pack_config}");
    # 判断icon是不是绝对路径，即不包含://
    if [[ ! "${pack_package_icon}" =~ :// ]]; then
        pack_package_icon="${pack_dir}/${pack_package_icon}";
    fi

    local url=$(jq -r '.url' "${pack_config}");
    local width=$(jq -r '.width' "${pack_config}");
    local height=$(jq -r '.height' "${pack_config}");

    local cmd="${url} --name ${name} --icon ${pack_package_icon} --width ${width} --height ${height}";

    local fullscreen=$(jq -r '.fullscreen' "${pack_config}");
    if [ "${fullscreen}" = "true" ]; then
        local cmd="${cmd_options} --fullscreen";
    fi

    local hideTitleBar=$(jq -r '.hideTitleBar' "${pack_config}");
    if [ "${hideTitleBar}" = "true" ]; then
        local cmd="${cmd_options} --hide-title-bar";
    fi

    echo "${cmd}";
}

# 解压deb包，并归档到target/
extract_deb() {
    local deb_file="$1";
    local pack_name=$(basename -s .deb "${deb_file}");

    echo "Extracting ${pack_name} ...";

    mkdir -p "${pack_name}";

    bsdtar -xOf "${deb_file}" data.tar.gz | bsdtar -xJf - -C "${pack_name}";

    # rename pake to pack_name
    find alimail/ -name "pake*" -type f | while read -r pake_name_file; do
        mv "${pake_name_file}" "${pake_name_file//pake/${pack_name}}";
    done

    # desktop file
    sed -i "s/pake/${pack_name}/g" "${pack_name}/usr/share/applications/${pack_name}.desktop"

    if tar caf "target/${pack_name}.tar.gz" "${pack_name}/"; then
        rm -r "${pack_name}";
    fi

    echo "archived at: target/${pack_name}.tar.gz";
}


rm -r target;
mkdir -p target;
find ./ -name "*.json" -type f | while read -r pack_config_path; do
    pack_package_name=$(jq -r '.name' "${pack_config_path}");

    echo "Start building package: ${pack_package_name} ...";

    # 记录开始时间
    start_time=$(date +%s);

    cmd_options=$(build_pake_options "${pack_package_name}" "${pack_config_path}");

    echo "Using cmd : '${cmd_options}'";

    if ! pake ${cmd_options} > /dev/null; then
        echo "Failed to build package: ${pack_package_name}.";
        exit 1;
    fi

    # 计算耗时
    end_time=$(date +%s);
    mv "${pack_package_name}.deb" target/;

    echo "Package ${pack_package_name} built successfully,at target/${pack_package_name}.deb, time consumed: $((end_time - start_time))s.";

    extract_deb "target/${pack_package_name}.deb";
done
