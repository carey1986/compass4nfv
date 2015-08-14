function destroy_nets() {
    sudo virsh net-destroy mgmt  2>&1
    sudo virsh net-undefine mgmt 2>&1
    sudo virsh net-destroy install  2>&1
    sudo virsh net-undefine install  2>&1
    rm -rf $COMPASS_DIR/deploy/work/network/*.xml
}

function setup_om_bridge() {
    ips=$(ip addr show $OM_NIC | grep 'inet ' | awk -F' ' '{print $2}')
    routes=$(ip route show | grep $OM_NIC)

    ip link set br_install down
    ip addr flush $OM_NIC
    brctl delbr br_install

    brctl addbr br_install
    brctl addif br_install $OM_NIC
    ip link set br_install up

    for ip in $ips; do
        ip addr add $ip dev br_install
    done

    echo "$routes" | while read line; do
        echo $line | sed "s/$OM_NIC/br_install/g" | xargs ip route add
    done
}

function setup_om_nat() {
    # create install network
    sed -e "s/REPLACE_BRIDGE/br_install/g" \
        -e "s/REPLACE_NAME/install/g" \
        -e "s/REPLACE_GATEWAY/$INSTALL_GW/g" \
        -e "s/REPLACE_MASK/$INSTALL_MASK/g" \
        -e "s/REPLACE_START/$INSTALL_IP_START/g" \
        -e "s/REPLACE_END/$INSTALL_IP_END/g" \
        $COMPASS_DIR/deploy/template/network/nat.xml \
        > $WORK_DIR/network/install.xml
    
    sudo virsh net-define $WORK_DIR/network/install.xml
    sudo virsh net-start install
}

function create_nets() {
    destroy_nets
    
    # create mgmt network
    sed -e "s/REPLACE_BRIDGE/br_mgmt/g" \
        -e "s/REPLACE_NAME/mgmt/g" \
        -e "s/REPLACE_GATEWAY/$MGMT_GW/g" \
        -e "s/REPLACE_MASK/$MGMT_MASK/g" \
        -e "s/REPLACE_START/$MGMT_IP_START/g" \
        -e "s/REPLACE_END/$MGMT_IP_END/g" \
        $COMPASS_DIR/deploy/template/network/nat.xml \
        > $WORK_DIR/network/mgmt.xml
    
    sudo virsh net-define $WORK_DIR/network/mgmt.xml
    sudo virsh net-start mgmt
    
    # create install network
    if [[ ! -z $VIRT_NUMBER ]];then
        setup_om_nat
    else
        setup_om_bridge
    fi
}

