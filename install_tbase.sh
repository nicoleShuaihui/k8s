function tbase_oss_agent_install_exec()
{
    local fname=$1
    local version=$2
    local type=$3
    local xz_agent_eth=$4
    local xz_agent_host=$5    
    local oss_all_iplist=$6
    local frpm="tbase_oss"
    local xz_agent_role="OssAgent"
    local oss_role="Agent"
    local tbase_oss_install_dir=${OSS_Pgxzm_Install_Dir}

    LOGINFO "[ $fname ] [INFO]: begin version=${version} frpm=${frpm} is_master=${xz_is_master}, host=${xz_agent_host} oss_all_iplist=${oss_all_iplist} "

    ####################################################################################################################
    ##安装tbase_oss rpm包
    ####################################################################################################################
    local exec_command="yum remove -y ${frpm} && yum -y install ${frpm}"
    (exec_ssh $fname ${SuperUser} $xz_agent_host $exec_command < /dev/null)
    if [ $? -ne 0 ]
    then
        LOGINFO "[ $fname ] [ERROR]: Fail to exec_command=$exec_command on $xz_agent_host"
        return ${RET_EXIT}
    fi

    LOGINFO "[ $fname ] [INFO]: begin tbase_oss_install_dir=${tbase_oss_install_dir}, rpm_oss_install_dir=${rpm_oss_install_dir}... "
  
    ####################################################################################################################
    ##清空tbase_oss运行目录，准备拷贝运行文件到目录下面
    ####################################################################################################################
    exec_command="rm -rf ${tbase_oss_install_dir} && mkdir -p ${tbase_oss_install_dir} && cp -r ${rpm_oss_install_dir}/* ${tbase_oss_install_dir}"
    (exec_ssh $fname ${SuperUser} $xz_agent_host $exec_command < /dev/null)
    if [ $? -ne 0 ]
    then
	LOGINFO "[ $fname ] [ERROR]: Fail to exec_command=$exec_command on $xz_agent_host"
        return ${RET_EXIT}
    fi

    exec_command="sed -i \"s/DEF_USER=tbase/DEF_USER=${PGXZ_OS_USER}/g\" ${tbase_oss_install_dir}/tools/op/common.sh"
    (exec_ssh $fname ${SuperUser} $xz_agent_host $exec_command < /dev/null)
    if [ $? -ne 0 ]
    then
        LOGINFO "[ $fname ] [ERROR]: Fail to exec_command=$exec_command on $xz_agent_host"
        return ${RET_EXIT}
    fi


    LOGINFO "[ $fname ] [INFO]: begin SCRIPT_deploy_pgxzm=${SCRIPT_deploy_pgxzm}... "

    ####################################################################################################################
    ##拷贝文件 deploy_pgxzm.sh
    ####################################################################################################################
    #(exec_scp $fname ${SuperUser} $xz_agent_host ${SCRIPT_deploy_pgxzm} ${tbase_oss_install_dir} < /dev/null)
    #if [ $? -ne 0 ]
    #then
    #    return ${RET_EXIT}
    #fi

    ####################################################################################################################
    ##拷贝文件 start_monitor.sh
    ####################################################################################################################
    LOGINFO "[ $fname ] [INFO]: begin TBASE_OSS_MON_SCRIPT_PATH=${TBASE_OSS_MON_SCRIPT_PATH}... "    
    (exec_scp $fname ${SuperUser} $xz_agent_host ${TBASE_OSS_MON_SCRIPT_PATH} ${tbase_oss_install_dir}/script < /dev/null)
    if [ $? -ne 0 ]
    then
        return ${RET_EXIT}
    fi

    LOGINFO "[ $fname ] [INFO]: tbase_oss_agent_install_exec begin start_monitor.sh "
    
    exec_command="dos2unix ${tbase_oss_install_dir}/script/start_monitor.sh; chmod a+x ${tbase_oss_install_dir}/script/start_monitor.sh"
    (exec_ssh $fname ${SuperUser} $xz_agent_host $exec_command < /dev/null)
    if [ $? -ne 0 ]
    then
        return ${RET_EXIT}
    fi

    ####################################################################################################################
    ##为tbase_oss生成tar包
    ####################################################################################################################
    LOGINFO "[ $fname ] [INFO]: tbase_oss_agent_install_exec begin  generate tar package for oss"    
    tar_name=`echo "tbase_oss_${version}_${type}.tar.gz"`
    LOGINFO "[ $fname ] [INFO]: tbase_oss_gen_tar_gz tar_name=${tar_name}"
    #tbase_oss_gen_tar_gz ${xz_agent_host} ${version} ${tar_name}
    #if [ $? -ne 0 ]
    #then
    #    return ${RET_EXIT}
    #fi
    
    
    
    LOGINFO "[ $fname ] [INFO]: tbase_oss_gen_config_file ${oss_role} ${xz_agent_host} ${oss_all_iplist} ${version} ${bind_net_frame}"
    tbase_oss_gen_config_file ${oss_role} ${xz_agent_host} ${oss_all_iplist} ${version} ${xz_agent_eth}
    if [ $? -ne 0 ]
    then
        return ${RET_EXIT}
    fi

   
    ####################################################################################################################
    ##将Oss的安装的信息记录到数据库中
    ####################################################################################################################
    get_machine_array_index ${xz_agent_host}
    ip_idx=$?
    if [ $ip_idx == -1 ]
    then
        LOGINFO "[ $fname ] [INFO]: Can't get machine index from array for ip=${xz_agent_host}"
        return ${RET_EXIT}
    fi
    
    idc_name=${MachineIdc[$ip_idx]}
    LOGINFO "[ $fname ] [INFO]: machine index=$ip_idx from array for ip=${xz_center_host}, idc_name=$idc_name"
    get_idc_name_index $idc_name
    idc_idx=$?
    if [ $idc_idx == -1 ]
    then
        LOGINFO "[ $fname ] [ERROR]: Can't get idc_name index from array for idc=${idc_name}"
        return ${RET_EXIT}
    fi

    idc_region=${IdcRegions[$idc_idx]}  
    
    sql="INSERT INTO pgxzm_oss.tbl_oss_agent_info(ip, port, role, version, region, idc_name, install_dir) VALUES('${xz_agent_host}', '${OSS_Agent_Port}', 'Agent','${version}', '${idc_region}', '${idc_name}', '${tbase_oss_install_dir}');"
    
    LOGINFO "[ $fname ] [INFO]: exec_command=${sql}"
    (query_confdb $fname $sql < /dev/null)
    if [ $? -ne 0 ]
    then
        return ${RET_EXIT}
    fi
    
    (exec_chown $fname $xz_agent_host </dev/null)
    if [ $? -ne 0 ]
    then
        return ${RET_EXIT}
    fi

    ####################################################################################################################
    ##启动oss_server
    ####################################################################################################################
    (tbase_oss_agent_start_exec $fname $xz_agent_host < /dev/null)
    if [ $? -ne 0 ]
    then
        return ${RET_EXIT}
    fi
    
    local exec_status=0
    local retry_wait=0
    local retry_sleep=${RETRY_SLEEP}

    LOGINFO "[ $fname ] [INFO]: ${retry_wait} Waiting for ${xz_agent_role} ${xz_agent_host} to start ... "
    sleep ${retry_sleep}
    (tbase_oss_agent_status_exec $fname $xz_agent_host </dev/null)
    exec_status=$?

    while [ "X$exec_status" != "X${BOOL_YES}" ]
    do
        (tbase_oss_agent_start_exec $fname $xz_agent_host < /dev/null)
        if [ $? -ne 0 ]
        then
            return ${RET_EXIT}
        fi

        let retry_wait++
        LOGINFO "[ $fname ] [INFO]: ${retry_wait} Waiting for ${xz_agent_role} ${xz_agent_host} to start ... "
        sleep ${retry_sleep}

        (tbase_oss_agent_status_exec $fname $xz_agent_host </dev/null)
        exec_status=$?
        if [ "X$exec_status" == "X${BOOL_YES}" ]
        then
            return 0
        fi

        if [ $retry_wait -gt ${RETRY_WAIT} ]
        then
            LOGINFO "[ $fname ] [ERROR]: Failed to start ${xz_agent_role} ${xz_agent_host} after waiting $(expr ${retry_wait}*${retry_sleep}) seconds, exit ... "
            return ${RET_EXIT}
        fi
    done
    
    #exec_command="curl \"http://${XZOssCenterMaster}:${OSS_Server_Port}/sys/query/\" "
    #LOGINFO "[ $fname ] [INFO]: Begin exec_command=${exec_command}"
    
    #(exec_cmd $fname $exec_command </dev/null)
    #if [ $? -ne 0 ]
    #then
    #    LOGINFO "[ $fname ] [INFO]: Fail to execute exec_command=${exec_command}"
    #    return ${RET_EXIT}
    #fi
}

function tbase_oss_agent_install()
{
    local fname=$FUNCNAME
    local idx=0
    local yum_dir=$PGXZ_YUM_DIR
    local version="0"
    local type="i"
    local oss_all_ips=$XZOssCenterMaster
    
    LOGINFO "[ $fname ] [INFO]: begin $XZOssCenterMasterEth, $XZOssCenterMaster "
    
    ####################################################################################################################
    ##解析tbase_oss―$version-$type rpm安装包
    ####################################################################################################################
    local rpm_cnt=$(find $yum_dir -name tbase_oss*.rpm | wc -l)
    echo "count(tbase_oss*.rpm)=${rpm_cnt}"
    if [ $rpm_cnt -ne 1 ]
    then
        LOGINFO "[ $fname ] [INFO]: There are ${rpm_cnt} tbase_oss*.rpm in $yum_dir, It should remove some redundants ~~~ "
        return ${RET_EXIT}
    fi

    for f in $(find $yum_dir -name tbase_oss*.rpm)
    do
        local frpmname=$(basename $f)
        local frpmcnt=$(find $yum_dir -name $frpmname | wc -l)

        if [ $frpmcnt -ne 1 ]
        then
            LOGINFO "[ $fname ] [INFO]: Fount $frpmcnt $frpmname in $yum_dir, It should remove some redundants ~~~ "
            return ${RET_EXIT}
        fi

        version=`echo ${frpmname} |cut -d'-' -f2`
        type=`echo ${frpmname} |cut -d'-' -f3 |cut -d'.' -f1`
    done
    
    TBASE_OSS_VERSION=$version
    
    ####################################################################################################################
    ##拼接所有的ip地址，例如：ip1,ip2,ip3
    ####################################################################################################################
    for host in ${XZOssCenterSlave[*]}
    do
        oss_all_ips=`echo "${oss_all_ips},${host}"`
    done
    
    LOGINFO "[ $fname ] [INFO]:  version=${version}, type=${type}, oss_all_ips=${oss_all_ips}"

    ####################################################################################################################
    ##Install all Oss Agent
    ####################################################################################################################
    for host in ${XZOssAgent[*]}
    do
        local xz_agent_host=${host}
        (tbase_oss_agent_install_exec $fname $version $type ${XZOssAgentEth[$idx]} $xz_agent_host $oss_all_ips </dev/null)
        if [ $? -ne 0 ]
        then
            LOGINFO "[ $fname ] [ERROR]: Fail to install OssAgent on host=${xz_agent_host}"
            return ${RET_EXIT}
        fi
        let idx++
    done
    
    return 0
}

########################################################################################################################
# Install Zookeeper
########################################################################################################################

function tbase_zookeeper_gen_config()
{
    local fname=$FUNCNAME
    local my_ip=$1  
    local zk_data_dir=$2
    local zk_log_dir=$3
    local zk_conf_dir=$4
    local jdk_bin=${rpm_jdk_install_dir}/bin
    local zk_run_dir=${OSS_ZK_Install_Dir}
    local zk_clt_port=${OSS_ZK_CLIENT_PORT}
    local zk_conn_m_port=${OSS_ZK_CONN_MASTER_PORT}
    local zk_elect_m_port=${OSS_ZK_ELECT_MASTER_PORT}
    local loop=0
    local my_id=-1
    local conf_str=""

#server.0=172.16.0.17:2888:3888
#server.1=172.16.0.24:2888:3888
#server.2=172.16.0.45:2888:3888
    
    LOGINFO "[ $fname ] [INFO]: generate zookeeper config XZZKServers=${XZZKServers[@]}, jdk_bin=${jdk_bin}, zk_run_dir=${zk_run_dir}"

    for ips in ${XZZKServers[@]}  
    do  
        conf_str=${conf_str}"\nserver.${loop}=${ips}:${zk_conn_m_port}:${zk_elect_m_port}"
        
        if [ "X$my_ip" == "X$ips" ]
        then
            my_id=$loop
        fi
        let loop++ 
    done  

    LOGINFO "[ $fname ] [INFO]: generate zookeeper config XZZKServers=${XZZKServers[@]}, conf_str=${conf_str}"
    
    ####################################################################################################################
    ##generate config file
    ####################################################################################################################
    exec_command="echo -e \\\"maxClientCnxns=0\n# The number of milliseconds of each tick\ntickTime=2000\n# The number of ticks that the initial\n# synchronization phase can take\ninitLimit=10\n# The number of ticks that can pass between\n# sending a request and getting an acknowledgement\nsyncLimit=5\n# the directory where the snapshot is stored.\ndataDir=${zk_data_dir}\n# the directory where the transaction logs are stored.\ndataLogDir=${zk_log_dir}\n# the port at which the clients will connect\nclientPort=${zk_clt_port}\n${conf_str}\nminSessionTimeout=4000\nmaxSessionTimeout=100000\\\" > ${zk_conf_dir}/zoo.cfg; chown ${PGXZ_OS_USER}: ${zk_conf_dir}/zoo.cfg"
    
    LOGINFO "[ $fname ] [INFO]: execute exec_command=${exec_command}"    
    (exec_ssh $fname ${SuperUser} $my_ip $exec_command < /dev/null)
    if [ $? -ne 0 ]
    then
        LOGINFO "[ $fname ] [ERROR]: Fail to execute exec_command=${exec_command}"
        return ${RET_EXIT}
    fi
    
    
    exec_command="echo -e \\\"${my_id}\\\" > ${zk_data_dir}/myid; chown ${PGXZ_OS_USER}: ${zk_data_dir}/myid"
    LOGINFO "[ $fname ] [INFO]: execute exec_command=${exec_command}"
    (exec_ssh $fname ${SuperUser} $my_ip $exec_command < /dev/null)
    if [ $? -ne 0 ]
    then
        LOGINFO "[ $fname ] [ERROR]: Fail to execute exec_command=${exec_command}"
        return ${RET_EXIT}
    fi
	
    exec_command="echo -e \\\"\n\nexport PATH=${jdk_bin}:$PATH\nexport ZOO_LOG_DIR=${zk_run_dir}/log\n\\\" >> ${PGXZ_OS_HOME}/.bashrc; chown ${PGXZ_OS_USER}: ${PGXZ_OS_HOME}/.bashrc"
    LOGINFO "[ $fname ] [INFO]: execute exec_command=${exec_command}"
    (exec_ssh $fname ${SuperUser} $my_ip $exec_command < /dev/null)
    if [ $? -ne 0 ]
    then
        LOGINFO "[ $fname ] [ERROR]: Fail to execute exec_command=${exec_command}"
        return ${RET_EXIT}
    fi
}


# (tbase_zookeeper_start_exec $fname $xz_zk_host </dev/null)
function tbase_zookeeper_start_exec()
{
    local fname=$1
    local xz_zk_host=$2
    local jdk_bin=${rpm_jdk_install_dir}
    local zk_run_dir=${OSS_ZK_Install_Dir}

    exec_command="su ${PGXZ_OS_USER} -c ' source ${PGXZ_OS_HOME}/.bashrc && dos2unix ${zk_run_dir}/bin/*.sh; chmod +x ${zk_run_dir}/bin/*.sh; mkdir -p ${zk_run_dir}/log/op_logs; export=${jdk_bin}:$PATH; ${zk_run_dir}/bin/zkServer.sh start >  ${zk_run_dir}/log/op_logs/zk_start.log 2>&1; echo 0 ' "
    
    LOGINFO "[ $fname ] [INFO]: Begin exec_command=${exec_command} xz_zk_host=${xz_zk_host}"
    
    (exec_ssh $fname ${SuperUser} $xz_zk_host $exec_command < /dev/null)
    if [ $? -ne 0 ]
    then
        LOGINFO "[ $fname ] [INFO]: Fail to execute exec_command=${exec_command} xz_zk_host={xz_zk_host}"
        return ${RET_EXIT}
    fi

    (pgxzm_crontab_add $fname $xz_zk_host < /dev/null)
    if [ $? -ne 0 ]
    then
        return ${RET_EXIT}
    fi
}

# (tbase_zookeeper_stop_exec $fname $xz_zk_host </dev/null)
function tbase_zookeeper_stop_exec()
{
    local fname=$1
    local xz_zk_host=$2
    local jdk_bin=${rpm_jdk_install_dir}
    local zk_run_dir=${OSS_ZK_Install_Dir}
    
    (pgxzm_crontab_remove $fname $xz_zk_host < /dev/null)
    if [ $? -ne 0 ]
    then
        return ${RET_EXIT}
    fi

     local exec_command="su ${PGXZ_OS_USER} -c ' source ${PGXZ_OS_HOME}/.bashrc && dos2unix ${zk_run_dir}/bin/*.sh; chmod +x ${zk_run_dir}/bin/*.sh; mkdir -p ${zk_run_dir}/log/op_logs; export=${jdk_bin}:$PATH; ${zk_run_dir}/bin/zkServer.sh stop >  ${zk_run_dir}/log/op_logs/zk_stop.log 2>&1; echo 0 ' "
    
    
    LOGINFO "[ $fname ] [INFO]: Begin exec_command=${exec_command} xz_zk_host=${xz_zk_host}"
    (exec_ssh $fname ${SuperUser} $xz_zk_host $exec_command < /dev/null)
    
    if [ $? -ne 0 ]
    then
        LOGINFO "[ $fname ] [INFO]: Fail to execute exec_command=${exec_command} xz_zk_host={xz_zk_host}"
        return ${RET_EXIT}
    fi
}

# (tbase_zookeeper_status_exec $fname $xz_zk_host </dev/null)
function tbase_zookeeper_status_exec()
{
    local fname=$1
    local xz_zk_host=$2
    local jdk_bin=${rpm_jdk_install_dir}
    local zk_run_dir=${OSS_ZK_Install_Dir}

    local exec_command="su ${PGXZ_OS_USER} -c ' source ${PGXZ_OS_HOME}/.bashrc && dos2unix ${zk_run_dir}/bin/*.sh; chmod +x ${zk_run_dir}/bin/*.sh; mkdir -p ${zk_run_dir}/log/op_logs; export=${jdk_bin}:$PATH; ${zk_run_dir}/bin/zkServer.sh status >  ${zk_run_dir}/log/op_logs/zk_status.log 2>&1; echo 0 ' "
    
    LOGINFO "[ $fname ] [INFO]: Begin exec_command=${exec_command} xz_zk_host=${xz_zk_host}"
    (exec_ssh $fname ${SuperUser} $xz_zk_host $exec_command < /dev/null)
        
    if [ $? -ne 0 ]
    then
        LOGINFO "[ $fname ] [ERROR]: Failed to exec: $exec_command on $xz_zk_host" 
        
        exec_command="su ${PGXZ_OS_USER} -c ' ps -ef |grep zookeeper |grep -v grep; ' "
        LOGINFO "[ $fname ] [INFO]: Begin exec_command=${exec_command} xz_zk_host=${xz_zk_host}"
        (exec_ssh $fname ${SuperUser} $xz_zk_host $exec_command < /dev/null)
        
        if [ $? -ne 0 ]
        then
            LOGINFO "[ $fname ] [ERROR]: Failed to exec: $exec_command on $xz_zk_host" 
            return return $BOOL_NO
        else
            return return $BOOL_YES
        fi
    else
        return $BOOL_YES
    fi
}

# (tbase_zookeeper_install_exec $fname $myip </dev/null)
function tbase_zookeeper_install_exec()
{
    local fname=$1
    local xz_zk_host=$2    
    local zk_all_iplist=${XZZKServers[@]}
    local zk_clt_port=${OSS_ZK_CLIENT_PORT}
    local zk_conn_m_port=${OSS_ZK_CONN_MASTER_PORT}
    local zk_elect_m_port=${OSS_ZK_ELECT_MASTER_PORT}
    local frpm="pgxzm_jdk tbase_zookeeper"
    local tbase_zk_install_dir=${OSS_ZK_Install_Dir}
    local zk_data_dir="${tbase_zk_install_dir}/data/"
    local zk_log_dir="${tbase_zk_install_dir}/log/"
    local zk_conf_dir="${tbase_zk_install_dir}/conf/"

    LOGINFO "[ $fname ] [INFO]: begin xz_zk_host=${xz_zk_host} frpm=${frpm} zk_all_iplist=${zk_all_iplist}, zk_clt_port=${zk_clt_port} zk_conn_m_port=${zk_conn_m_port} zk_elect_m_port=${zk_elect_m_port} "

    ####################################################################################################################
    ##install jdk and zookeeper package
    ####################################################################################################################
    local exec_command="yum remove -y ${frpm} && yum -y install ${frpm}"
    (exec_ssh $fname ${SuperUser} $xz_zk_host $exec_command < /dev/null)
    if [ $? -ne 0 ]
    then
        return ${RET_EXIT}
    fi

    LOGINFO "[ $fname ] [INFO]: begin tbase_zk_install_dir=${tbase_zk_install_dir}, rpm_zk_install_dir=${rpm_zk_install_dir}... "
  
    ####################################################################################################################
    ##clear the zookeeper run dir and copy the install file to the run dir
    ####################################################################################################################
    exec_command="rm -rf ${tbase_zk_install_dir} && mkdir -p ${tbase_zk_install_dir} && cp -r ${rpm_zk_install_dir}/* ${tbase_zk_install_dir} && mkdir -p ${zk_data_dir} && mkdir -p ${zk_log_dir} && mkdir -p ${zk_log_dir}/op_logs && chown ${PGXZ_OS_USER}: ${tbase_zk_install_dir} -R "
    (exec_ssh $fname ${SuperUser} $xz_zk_host $exec_command < /dev/null)
    if [ $? -ne 0 ]
    then
        return ${RET_EXIT}
    fi

    #LOGINFO "[ $fname ] [INFO]:  begin start_monitor.sh "
    
    #exec_command="chmod a+x ${tbase_oss_install_dir}/script/start_monitor.sh"
    #(exec_ssh $fname ${SuperUser} $xz_agent_host $exec_command < /dev/null)
    #if [ $? -ne 0 ]
    #then
    #    return ${RET_EXIT}
    #fi

    ####################################################################################################################
    ##generate zookeeper config
    ####################################################################################################################
        
    LOGINFO "[ $fname ] [INFO]: tbase_zookeeper_gen_config ${xz_zk_host} ${zk_data_dir} ${zk_log_dir} ${zk_conf_dir}"
    tbase_zookeeper_gen_config ${xz_zk_host} ${zk_data_dir} ${zk_log_dir} ${zk_conf_dir}
    if [ $? -ne 0 ]
    then
        LOGINFO "[ $fname ] [ERROR]: Fail to tbase_zookeeper_gen_config ${xz_zk_host} ${zk_data_dir} ${zk_log_dir} ${zk_conf_dir}"
        return ${RET_EXIT}
    fi

   
    ####################################################################################################################
    ##start zookeeper
    ####################################################################################################################
    (tbase_zookeeper_start_exec $fname $xz_zk_host < /dev/null)
    if [ $? -ne 0 ]
    then
        LOGINFO "[ $fname ] [ERROR]: Fail to start zookeeper for ${xz_zk_host}"
        return ${RET_EXIT}
    fi
    
    local exec_status=0
    local retry_wait=0
    local retry_sleep=${RETRY_SLEEP}

    LOGINFO "[ $fname ] [INFO]: ${retry_wait} Waiting for ${xz_zk_host} to start ... "
    sleep ${retry_sleep}
    (tbase_zookeeper_status_exec $fname $xz_zk_host </dev/null)
    exec_status=$?

    while [ "X$exec_status" != "X${BOOL_YES}" ]
    do
        (tbase_zookeeper_start_exec $fname $xz_zk_host < /dev/null)
        if [ $? -ne 0 ]
        then
            return ${RET_EXIT}
        fi

        let retry_wait++
        LOGINFO "[ $fname ] [INFO]: ${retry_wait} Waiting for ${xz_zk_host} to start ... "
        sleep ${retry_sleep}

        (tbase_zookeeper_status_exec $fname $xz_zk_host </dev/null)
        exec_status=$?
        if [ "X$exec_status" == "X${BOOL_YES}" ]
        then
            return 0
        fi

        if [ $retry_wait -gt ${RETRY_WAIT} ]
        then
            LOGINFO "[ $fname ] [ERROR]: Failed to start ${xz_zk_host} after waiting $(expr ${retry_wait}*${retry_sleep}) seconds, exit ... "
            return ${RET_EXIT}
        fi
    done
    
    #exec_command="curl \"http://${XZOssCenterMaster}:${OSS_Server_Port}/sys/query/\" "
    #LOGINFO "[ $fname ] [INFO]: Begin exec_command=${exec_command}"
    
    #(exec_cmd $fname $exec_command </dev/null)
    #if [ $? -ne 0 ]
    #then
    #    LOGINFO "[ $fname ] [INFO]: Fail to execute exec_command=${exec_command}"
    #    return ${RET_EXIT}
    #fi
}

function tbase_zookeeper_install()
{
    local fname=$FUNCNAME
    local idx=0
    local yum_dir=$PGXZ_YUM_DIR
    
    LOGINFO "[ $fname ] [INFO]: begin install all zookeeper ${XZZKServers[@]} IS_USED_ZK=$IS_USED_ZK"

    if [ $IS_USED_ZK -ne 1 ]
    then
        LOGINFO "[ $fname ] [INFO]: It desn't install zookeeper, is_used_zk=$IS_USED_ZK"
	return 0
    fi

    ####################################################################################################################
    ##Install zookeeper according ip
    ####################################################################################################################
    for host in ${XZZKServers[*]}
    do
        local xz_zk_host=${host}
        (tbase_zookeeper_install_exec $fname $xz_zk_host </dev/null)
        if [ $? -ne 0 ]
        then
            LOGINFO "[ $fname ] [ERROR]: Fail to install zookeeper on host=${xz_zk_host}"
            return ${RET_EXIT}
        fi
        let idx++
    done
    
    return 0
}

function print_step()
{
    echo
    echo -e "Hey, Welcome and now we will install TBase OSS by the flowing steps: "
    echo -e "\n\t0.  Check role configuration read from conf/$(basename $ROLE_INFO) ... "
    echo -e "\n\t1.  Install some base rpm packages such as dos2unix/createrepo/expect and so on ... "
    echo -e "\n\t2.  Check root password and do some initalization on all machines read from conf/$(basename $ROLE_INFO) ... "
    echo -e "\n\t3.  Check package requires ... "
    echo -e "\n\t4.  Create OS user ${PGXZ_OS_USER} specifided in conf/oss/oss_init.conf  ... "
    echo -e "\n\t5.  Create yum repository which store all the rpm packages needed by TBase OSS ... "
    echo -e "\n\t6.  Install and Start Etcds ... "
    echo -e "\n\t7.  Install and Start all Confdb ... "
    echo -e "\n\t8.  Install and Start Alarm Server ... "
    echo -e "\n\t9.  Install and Start OssCenterMaster and all OssCenterSlaves ... "  
    echo -e "\n\t10. Install and Start all Agents ... "  
    echo -e "\n\t11. Install default tbase_pgxz package... "    
    echo -e "\n\t12. Install and Start Tstudio ... "
    echo -e "\nReady to continue (Yy|Nn) ? "

    while true
    do   
        read option 
        case "$option" in   
            y|Y|yes|YES)
                return 0
                ;;  
            n|N|no|NO)
                exit ${RET_EXIT}
                ;;  
            * )
                echo -e "\nReady to continue (Yy|Nn) ? "
                ;;
        esac  
    done
}

function check_progress()
{
    local fname=$FUNCNAME
    local retcode=$1
    local last_fname=$2

    if [ $retcode -ne 0 ]
    then
        LOGINFO "[ $fname ] [ERROR]: from [$last_fname] Abort progress due to an error occurs during step above, check logs/${shellLog} for more details ... " > /dev/null 2>&1
        echo -e "\n\t[ERROR]: from [$last_fname] Abort progress due to an error occurs during step above, check logs/${shellLog} for more details ... "
        exit ${RET_EXIT}
    fi
}

function install_tbase_oss()
{
    local fname=$FUNCNAME

    init

    local curr_step=0
    print_step

    ########################################################################################################

    echo -e "\n\t${curr_step}.  Now start to check role configuration ... "
    read_machine_info  > /dev/null 2>&1
    check_progress $? 'read_machine_info'

    check_machine_ip  > /dev/null 2>&1
    check_progress $? 'check_machine_ip'

    check_agent_ip  > /dev/null 2>&1
    check_progress $? 'check_agent_ip'

    check_confdb_ip  > /dev/null 2>&1
    check_progress $? 'check_confdb_ip'

    check_oss_server_ip  > /dev/null 2>&1
    check_progress $? 'check_oss_server_ip'

    check_yum_host  > /dev/null 2>&1
    check_progress $? 'check_yum_host'

    ########################################################################################################

    let curr_step++
    echo -e "\n\t${curr_step}.  Now start to install dos2unix/createrepo/expect and so on ... "
    install_base_rpm  > /dev/null 2>&1
    check_progress $? 'install_base_rpm'

    gen_oss_xz_conf  > /dev/null 2>&1
    check_progress $? 'gen_oss_xz_conf'

    gen_oss_template_conf  > /dev/null 2>&1
    check_progress $? 'gen_oss_template_conf'

    ########################################################################################################

    let curr_step++
    echo -e "\n\t${curr_step}.  Now start to check root password and do some initalization on all machines ... "
    selinux_policy_off  > /dev/null 2>&1
    check_progress $? 'selinux_policy_off'

    ssh_root_keygen  > /dev/null 2>&1
    check_progress $? 'ssh_root_keygen'

    scp_root_sshkey  > /dev/null 2>&1
    check_progress $? 'scp_root_sshkey'

    push_root_sshkey  > /dev/null 2>&1
    check_progress $? 'push_root_sshkey'

    check_net_eth  > /dev/null 2>&1
    check_progress $? 'check_net_eth'

    rm_redundancy_rpms  > /dev/null 2>&1
    check_progress $? 'rm_redundancy_rpms'

    check_yum_repo  > /dev/null 2>&1
    check_progress $? 'check_yum_repo'

    scp_force_clean  > /dev/null 2>&1
    check_progress $? 'scp_force_clean'

    run_force_clean  > /dev/null 2>&1
    check_progress $? 'run_force_clean'

    ########################################################################################################

    let curr_step++
    echo -e "\n\t${curr_step}.  Now start to check package requires ... "
    deploy_packages  > /dev/null 2>&1
    check_progress $? 'deploy_packages'

    #check_requires  > /dev/null 2>&1
    #check_progress $? 'check_requires'

    ########################################################################################################

    let curr_step++
    echo -e "\n\t${curr_step}.  Now start to create OS user ${PGXZ_OS_USER} ... "
    clean_user_dir  > /dev/null 2>&1
    check_progress $? 'clean_user_dir'

    create_user  > /dev/null 2>&1
    check_progress $? 'create_user'

    exec_user_sshsetup  > /dev/null 2>&1
    check_progress $? 'exec_user_sshsetup'

    check_user_sshsetup  > /dev/null 2>&1
    check_progress $? 'check_user_sshsetup'

    ssh_chmod_privilege  > /dev/null 2>&1
    #check_progress $? 'ssh_chmod_privilege'
    ########################################################################################################

    let curr_step++
    echo -e "\n\t${curr_step}.  Now start to create yum repository ... "
    create_yum_repo  > /dev/null 2>&1
    check_progress $? 'create_yum_repo'

    conf_yum_repo  > /dev/null 2>&1
    check_progress $? 'conf_yum_repo'

    cgroup_install >  /dev/null 2>&1
    check_progress $? 'cgroup_install'

    ########################################################################################################

    let curr_step++
    echo -e "\n\t${curr_step}.  Now start to install Etcd ... "
    etcd_install  > /dev/null 2>&1
    check_progress $? 'etcd_install'

    ########################################################################################################

    let curr_step++
    echo -e "\n\t${curr_step}.  Now start to install all Confdbs ... "
    confdb_install  > /dev/null 2>&1
    check_progress $? 'confdb_install'

    ########################################################################################################

    let curr_step++
    echo -e "\n\t${curr_step}.  Now start to install Alarm Server ... "
    alarm_server_install  > /dev/null 2>&1
    check_progress $? 'alarm_server_install'
    
    ########################################################################################################

    let curr_step++
    echo -e "\n\t${curr_step}. Now start to install all OssCenters ... "
    tbase_oss_center_install  > /dev/null 2>&1
    check_progress $? 'tbase_oss_center_install'

    ########################################################################################################

    let curr_step++
    echo -e "\n\t${curr_step}. Now start to install all OssAgents ... "
    tbase_oss_agent_install  > /dev/null 2>&1
    check_progress $? 'tbase_oss_agent_install'
    
    ########################################################################################################

    let curr_step++
    echo -e "\n\t${curr_step}. Now start to install default tbase_pgxz... "
    tbase_pgxz_install  > /dev/null 2>&1
    check_progress $? 'tbase_pgxz_install'
    
    ########################################################################################################
    
    let curr_step++
    echo -e "\n\t${curr_step}. Now start to install TStudio ... "
    tstudio_install  > /dev/null 2>&1
    check_progress $? 'tstudio_install'
	
	let curr_step++
    echo -e "\n\t${curr_step}. Now start to write etcd keys ... "
    write_etcd_keys  > /dev/null 2>&1
    check_progress $? 'write_etcd_keys'
}

function write_etcd_keys()
{
	oss_center_key=/tbase_oss_conf/center_ip_list
	pri_elect_key=/tbase_oss_conf/center_pri_elect_key
	confdb_cluster_spec_key=/tbase_oss/confdb_cluster_spec
	#confdb_master_key=/tbase_oss/confdb_master

	
	local arb_cnt=${#XZEtcds[@]}
    tmp_list="${XZEtcds[0]}:${CLIENT_PORT[0]}"
    for (( i=1; i<${tmp_list}; i++ ));
    do
        tmp_list="${tmp_list},${XZEtcds[$i]}:${CLIENT_PORT[0]}"
    done
   
	ETCD_ENDPOINTS=$tmp_list
    LOGINFO "[ $fname ] [INFO]: tmp_list=${tmp_list} ETCD_ENDPOINTS=$ETCD_ENDPOINTS"
	
	## part1
	local confdb_cluster_spec_key_val="{\\\"master_cluster\\\":\\\"cluster01\\\"}"
	local exec_command="export ETCDCTL_API=3;etcdctl --endpoints=$ETCD_ENDPOINTS put $confdb_cluster_spec_key $confdb_cluster_spec_key_val"
	LOGINFO "[ $FUNCNAME ]exec_command=$exec_command"
    local exec_ret=$(echo "($exec_command)" | sh)
	if [ $? -ne 0 ]
    then
        return ${RET_EXIT}
    fi
	
	## part2
	local oss_center_key_val="$XZOssCenterMaster"
	for host in ${XZOssCenterSlave[*]} 
	do
		oss_center_key_val=$oss_center_key_val,$host
	done
	
	local exec_command="export ETCDCTL_API=3;etcdctl --endpoints=$ETCD_ENDPOINTS put $oss_center_key $oss_center_key_val"
	LOGINFO "[ $FUNCNAME ]exec_command=$exec_command"
    local exec_ret=$(echo "($exec_command)" | sh)
	if [ $? -ne 0 ]
    then
        return ${RET_EXIT}
    fi
	
	## part3
	local pri_elect_key_val="$XZOssCenterMaster"
	for host in ${XZOssCenterSlave[*]} 
	do
		pri_elect_key_val=$pri_elect_key_val,$host
	done
	
	local exec_command="export ETCDCTL_API=3;etcdctl --endpoints=$ETCD_ENDPOINTS put $pri_elect_key $pri_elect_key_val"
	LOGINFO "[ $FUNCNAME ]exec_command=$exec_command"
    local exec_ret=$(echo "($exec_command)" | sh)
	if [ $? -ne 0 ]
    then
        return ${RET_EXIT}
    fi
}

function report_success()
{
    local fname=$FUNCNAME

    echo
    echo
    echo "##################################################"
    echo "#                                                #"
    echo "#            ^_^ Congratulations ^_^             #"
    echo "#                                                #"
    echo "##################################################"
    echo
    echo

    LOGINFO "[ $fname ] [INFO]: Successed to install TBase OSS, visit http://${XZOssCenterMaster}:${OSS_Server_Port} to continue ... " > /dev/null 2>&1
    echo -e "Successed to install TBase OSS, visit http://${XZOssCenterMaster}:${OSS_Server_Port} to continue ...\n\n"
    echo -e "Successed to install TStudio, visit http://${XZTStudioServer}:${OSS_TStudio_Server_Port} \n"
    echo -e "default account: postgres@postgres.com password: postgres"
}

function print_usage()
{
    echo "$0 install:   run installation procedure"
    echo "$0 {start|stop|restart|status}: {OssCenter | OssAgent | Confdb | Alarm | TStudio | all} (ip)"
    echo "$0 help:   print this"
    exit 1;
}

function do_install()
{
    install_tbase_oss
    report_success
}

function do_print()
{
    case "$1" in
        start|stop|restart)
            if [ $2 == 0 ];then
                echo "$3 $1 success"
            else
                echo "$3 $1 failed"
            fi
            ;;
        status)
            if [ $2 == 0 ];then
                echo "$3 is running "
            else
                echo "$3 is stopped"
            fi
            ;;
    esac
}

function do_op_Confdb()
{
    local fname=$FUNCNAME
    #local XZConfdbs=${XZConfdb[*]}
    #XZConfdbs[${#XZConfdbs[@]}]=${XZConfdbs[0]}

    for host in ${XZConfdbs[*]}
    do
        if [ -z $3 ] || ( [ ! -z $3 ] && [ X"$host" == X"$3" ] )
        then
            (confdb_$1_exec $fname $host < /dev/null) &> /dev/null
            do_print $1 $? "Confdb  ${host}"
        fi
    done
}

function do_op_OssCenter()
{
    local fname=$FUNCNAME
    local XZCenters=${XZOssCenterSlave[*]}
    XZCenters[${#XZCenters[@]}]=$XZOssCenterMaster

    for host in ${XZCenters[*]}
    do
        if [ -z $3 ] || ( [ ! -z $3 ] && [ X"$host" == X"$3" ] )
        then
            (tbase_oss_center_$1_exec $fname $host </dev/null) &> /dev/null
            do_print $1 $? "OssCenter  ${host}"
        fi
    done
}
function do_op_OssAgent()
{
    local fname=$FUNCNAME

    for host in ${XZOssAgent[*]}
    do
        if [ -z $3 ] || ( [ ! -z $3 ] && [ X"$host" == X"$3" ] )
        then
            (tbase_oss_agent_$1_exec $fname $host </dev/null) &> /dev/null
            do_print $1 $? "OssAgent   ${host}"
        fi
    done 
}



function do_op_Alarm()
{
    alarm_server_$1 &> /dev/null
    do_print $1 $? "Alarm   ${XZAlarmServer}"
}

function do_op_TStudio()
{
    tstudio_server_$1 &> /dev/null
    do_print $1 $? "TStudio ${XZTStudioServer}"
}

function do_op()
{
    read_machine_info &> /dev/null
    check_progress $?

    case "$2" in
        OssCenter | Confdb | OssAgent | Alarm | TStudio)
            if [ $1 == "restart" ];then
                do_op_$2 stop $3
                do_op_$2 start $3
            else
                do_op_$2 $@
            fi
            ;;
        all)
            for part in Alarm TStudio Confdb OssCenter OssAgent  
            do
                if [ $1 == "restart" ];then
                    do_op_$part stop $3
                    do_op_$part start $3
                else
                    do_op_$part $@
                fi
            done
            ;;
        *)
            echo "$2 is not in (OssCenter | Confdb| OssAgent | Alarm | TStudio)"
            print_usage
            ;;
    esac
}

function do_switch_confdb_ip()
{
    read_machine_info &> /dev/null
    check_progress $?

    local cfg_path=${OSS_Pgxzm_Install_Dir}
    local XZCenters=${XZOssCenterSlave[*]}
    XZCenters[${#XZCenters[@]}]=$XZOssCenterMaster
    local target_ip=$2
    local fname=$FUNCNAME

    for host in ${XZCenters[*]}
    do
    	local exec_command="sed -i '/db_host/d' ${cfg_path}/config/tbase_oss_conf.ini && echo db_host=${target_ip} >> ${cfg_path}/config/tbase_oss_conf.ini"
    	(exec_ssh $fname ${SuperUser} $host $exec_command < /dev/null)
    	if [ $? -ne 0 ]
    	then
        	return ${RET_EXIT}
    	fi
    done

    for host in ${XZOssAgent[*]}
    do
    	local exec_command="sed -i '/db_host/d' ${cfg_path}/config/tbase_oss_conf.ini && echo db_host=${target_ip} >> ${cfg_path}/config/tbase_oss_conf.ini"
    	(exec_ssh $fname ${SuperUser} $host $exec_command < /dev/null)
    	if [ $? -ne 0 ]
    	then
        	return ${RET_EXIT}
    	fi
    done 

    echo "change confdb ip to $target_ip done,please restart oss"
	
}

########################################################################################################################
#
# tbase deploy main entry 
#
########################################################################################################################
case "$1" in
    start|stop|restart|status)
        do_op $@
        ;;
    install)
        do_install $@
        ;;
    switch_confdb)
	do_switch_confdb_ip $@
	;;
    *)
        print_usage
        ;;
esac