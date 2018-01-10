# guacamole-test1
## Preparing
Для сборки проекта понадобится аккаунт в AWS и установленный terraform, а так же пара ключей для доступа к AWS
```
git clone https://github.com/freddygood/guacamole-test1.git
cd guacamole-test1
```
## Configuration
Файл *variables.tf*
- aws_access_key - Ключ доступа AWS
- aws_secret_key - Скретный ключ доступа AWS
- application_name - Имя приложения, используется для именования ресурсов и тегов (*guacamole*)
- public_key_path - Путь к публичному ключу (*./mongodb-test-key.pub*)
- private_key_path - Путь к приватному ключу (*mongodb-test-key*). Оба ключа должны быть сгенерены заранее командой *ssh-keygen -t rsa -f mongodb-test-key*
- vpc_cidr_block - Блок IP-адресов для проекта (*10.0.0.0/16*)
- aws_region - Регион для размещения проекта (*us-west-1*)
- aws_azs - Список зон доступности для размещения проекта (*us-west-1a, us-west-1c*)
- aws_az_cidr_blocks - Список блоков IP-адресов, соответвтвующие зонам доступности из *aws_azs* (*10.0.0.0/24, 10.0.1.0/24*)
- aws_ami - Образ ОС для установки (*ami-a51f27c5*)
- instance_type - тип EC2 инстанса (*t2.micro*)
- instance_puppet_name - имя инстанса для разворачивания puppet (*mongodb-puppet*)
- instance_config_num - число инстансов серверов конфигурации (*3*)
- instance_config_name - имя инстансов серверов конфигураций (*mongodb-config*)
- instance_data_num - число инстансов серверов данных (*6*)
- instance_data_name - имя инстансов серверов данных (*mongodb-data*)
- instance_router_num - число инстансов серверов mongos (*2*)
- instance_router_name - имя инстансов серверов mongos (*mongodb-router*)
Имя инстанса формируется, как *instance_config_name-<num>*, где *num* - порядковый номер, для всех типов инстансов соответственно
- replset_mapping - карта replset-ов, описывает все наборы - и конфигураций, и данных. В формате *key* = имя replset-а, *value* = список серверов в нем
- instance_mapping - карта серверов. *Key* = сервер, *value* = replset, в который он входит
- router_mapping - конфиг для mongos. *Key* = config или data, *value* = имя replset-а серверов конфигураций или данных для добавления, как шарды
## Building
```
terraform init
terraform apply
```
## Result
Проект terraform создает в AWS
1. сетевую инфраструктуру - VPC, subnets, приватную DNS-зону и т.д.
2. инстанс puppet, создает на нем манифесты и hiera для всех инстансов mongodb
3. остальные инстансы и запускает на них puppet
4. puppet настраивает сервера соответственно назначению
5. на выходе выводит IP-адреса всех серверов
Для проверки можно зайти по ssh на сервер puppet - там уже установлен клиент mongo и выполнить:
```
mongo --host mongodb-router-1 --eval 'sh.status()'
mongo --host mongodb-config-1 --port 27019 --eval 'rs.status()'
mongo --host mongodb-data-1 --port 27018 --eval 'rs.status()'
```
## Production
1. Настроить безопасность в AWS по best practice - bastion host и отдельные правила firewall-а для разных хостов
2. Сделать возможность выбирать instance_type и диски для каждого типа инстанса
3. Настроить авторизацию в mongodb
