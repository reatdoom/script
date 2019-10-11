#!/bin/sh

export OS_PROJECT_DOMAIN_NAME=default
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=admin@yunzx
export OS_AUTH_URL=http://10.0.0.100:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2

#------------------------------
# 删除软删除的主机
#------------------------------

for i in `nova list --all-tenants --deleted|grep SOFT_DE| cut -d '|' -f 2`; do nova force-delete $i; done

#------------------------------
# 重启DHCP服务
#------------------------------

systemctl restart neutron-dhcp-agent.service
