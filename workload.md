# 工作负载（1）-Deployment

Kubernetes将设置pod的部署规则的对象称为工作负载（workload）。在部署应用时，我们通常不会直接创建pod。而是通过创建工作负载，让Kubernetes为我们创建和管理所需的pod。

常用的工作负载有如下5种：

* Deployment 无状态应用，对外提供的服务是应用
* Statefulset   有状态应有，存储集群。有一些是master，leader，绑定一个固定的存储
* Daemonset  守护，监控，采集类agent
* Job  任务，跑完就可以pod没有
* Cronjob 定时任务



### 1. Deployment基本操作

Kubernetes Deployment是用于部署无状态应用。在实践中，我们开发的**绝大部分应用都属于无状态应用**，因此Deployment也是五类工作负载中最常用的。

作为示例，我们来创建一个``deployment``。



**创建Deployment**

首先编辑一个``deploy.yml``，内容如下：

```
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  labels:
    app: super-front
    codename: k8s-playground
    project: k8s-playground
  name: super-front
  namespace: 【你的环境名】
spec:
  minReadySeconds: 30     # pod启动后，当liveness和readiness均为true之后，经过min ready seconds的时间后，则认为容器启动成功
  replicas: 1    # pod实例数。如果启用HPA，则以HPA预期实例数为准。
  selector:
    matchLabels:
      app: super-front
  strategy:
    rollingUpdate:
      maxSurge: 1    # 在滚动升级过程中，可超出预期 25% 向上取整replicas的pod个数。max unavailable和max surge不能同时为0，否则将无法滚动升级。
      maxUnavailable: 0   # 在滚动升级过程中，处于不可用状态的pod数的上限。max unavailable和max surge不能同时为0，否则将无法滚动升级。 理解有点选举里面的不可用，配置maxSurge要小，不要会更小 25%，向下取整
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: super-front
        project: k8s-playground
    spec:
      containers:
      - env:   # 环境变量。key-value的形式。key需符合Linux环境变量名字要求
        - name: LANG
          value: en_US.UTF-8
        - name: LANGUAGE
          value: en_US:en
        - name: LC_ALL
          value: en_US.UTF-8
        image: nginx:latest
        imagePullPolicy: Always
        livenessProbe:   # container的生存状态探针。若该探针返回异常状态，则重启container。
          failureThreshold: 3
          initialDelaySeconds: 168   # container启动后，首次执行liveness probe的延迟时间
          periodSeconds: 20   # liveness probe执行周期时间
          successThreshold: 1
          tcpSocket:
            port: 80
          timeoutSeconds: 1
        name: super-front
        readinessProbe:   # container准备状态探针。若该探针返回异常状态，则认为container未准备好处理请求
          failureThreshold: 3
          httpGet: 
            path: /
            port: 80
            scheme: HTTP #提供header与get两种服务
          initialDelaySeconds: 11
          periodSeconds: 20
          successThreshold: 1
          timeoutSeconds: 1
        resources:
          limits:
            cpu: 10m    #container占用的cpu资源上限
            memory: 64Mi    #container占用的内存资源上限
          requests:
            cpu: 10m    #container预留的cpu资源
            memory: 64Mi   #container预留的内存资源
      dnsPolicy: Default
      restartPolicy: Always
```



通过``kubectl apply``创建Deployment：

```
# kubectl apply -f ./deploy.yml 
deployment.extensions/super-front created
```



**获取查看Deployment**

```
# kubectl get deploy -n pg-allen
NAME          READY   UP-TO-DATE   AVAILABLE   AGE
super-front   1/1     1            1           4m28s
```



**查看对应的pod**

```
# kubectl get po -n pg-allen -l app=super-front
NAME                           READY   STATUS              RESTARTS   AGE
super-front-5788dc997d-k8prp   0/1     ContainerCreating   0          10s
```



**编辑修改**

```
# kubectl edit deploy -n pg-allen
# 按下回车后，将打开vi，可编辑deployment配置
```

在vi中保存并退出后，kubectl会检查配置，若配置无误将立即更新Deployment。

若Deployment的``spec.strategy``配置的升级策略为``rollingUpdate``，那么deployment更新后，pod将自动升级。

尝试将``image``改为``nginx:1.16.1-alpine``。

查看修改后Deployment的image：

```
# kubectl get deploy super-front -n pg-allen  -oyaml |grep image:
        image: nginx:1.16.1-alpine
```

查看当前Deployment的``revision``：

```
# kubectl get deploy super-front -n pg-allen  -oyaml  |grep revision
    deployment.kubernetes.io/revision: "2"
  revisionHistoryLimit: 10
  ... ...
```

可看出修改image后，revision为2。



**查看Deployment历史记录**

```
# kubectl rollout history deployment/super-front -n pg-allen
deployment.extensions/super-front 
REVISION  CHANGE-CAUSE
1         <none>
2         <none>
```



**回滚Deployment**

``kubectl rollout undo``命令可将deployment回滚到某次revision：

```
# kubectl rollout undo deployment/super-front -n pg-allen --to-revision=1
deployment.extensions/super-front rolled back
```

查看Deployment回滚后的image：

```
# kubectl get deploy super-front -n pg-allen  -oyaml |grep image:
        image: nginx:latest
```



**查看事件**

```
# kubectl describe deploy super-front -n pg-allen 
Name:                   super-front
Namespace:              pg-allen
CreationTimestamp:      Wed, 08 Apr 2020 10:53:40 +0800
Labels:                 app=super-front
                        codename=k8s-playground
                        project=k8s-playground
Annotations:            deployment.kubernetes.io/revision: 2
Selector:               app=super-front
Replicas:               1 desired | 1 updated | 1 total | 1 available | 0 unavailable
StrategyType:           RollingUpdate
MinReadySeconds:        30
RollingUpdateStrategy:  0 max unavailable, 1 max surge
Pod Template:
  Labels:           app=super-front
                    codename=k8s-playground
                    project=k8s-playground
  Annotations:      cluster-autoscaler.kubernetes.io/safe-to-evict: true
  Service Account:  default
  Containers:
   super-front:
    Image:      nginx:latest
    Port:       <none>
    Host Port:  <none>
    Limits:
      cpu:     10m
      memory:  64Mi
    Requests:
      cpu:      10m
      memory:   64Mi
    Liveness:   tcp-socket :80 delay=168s timeout=1s period=20s #success=1 #failure=3
    Readiness:  http-get http://:80/ delay=11s timeout=1s period=20s #success=1 #failure=3
    Environment:
      LANG:      en_US.UTF-8
      LANGUAGE:  en_US:en
      LC_ALL:    en_US.UTF-8
    Mounts:      <none>
  Volumes:       <none>
Conditions:
  Type           Status  Reason
  ----           ------  ------
  Available      True    MinimumReplicasAvailable
  Progressing    True    NewReplicaSetAvailable
OldReplicaSets:  <none>
NewReplicaSet:   super-front-5b9db6d78c (1/1 replicas created)
Events:
  Type    Reason             Age    From                   Message
  ----    ------             ----   ----                   -------
  Normal  ScalingReplicaSet  5m17s  deployment-controller  Scaled up replica set super-front-75cb9b56fc to 1
  Normal  ScalingReplicaSet  4m28s  deployment-controller  Scaled up replica set super-front-5b9db6d78c to 1
  Normal  ScalingReplicaSet  3m38s  deployment-controller  Scaled down replica set super-front-75cb9b56fc to 0
```



**导出Deployment配置**

``kubectl get deploy``添加``--export``后，可导出工作负载的配置：

```
# kubectl get deploy super-front -n pg-allen -oyaml --export  > deploy.yml
```



**删除Deployment**

```
# kubectl delete deploy super-front -n pg-allen 
deployment.extensions "super-front" deleted
```



另一种删除方式：

```
# kubectl delete -f ./deploy.yml
deployment.extensions "super-front" deleted
```

PS：当要清除/停用某个App时，只删除pod是不行的，必须删除产生这个pod的工作负载。



扩展阅读：

* Deployments：https://kubernetes.io/docs/concepts/workloads/controllers/deployment/

# 工作负载（2）-Statefulset

除了无状态应用（Deployment）外，实践中还存在另一种不那么常见的应用：有状态应用。有状态应用通常有如下特点：

* 需要固定的网络标识符（通过Headless Service实现）。例如，Redis集群里面的多个Redis实例，相互之间需要固定的IP或hostname等网络标识进行访问。
* 需要稳定的存储（通过PV/PVC实现）。例如，Zookeeper集群中各个实例，需要单独且固定的存储。
* 实例可按固定顺序创建、删除、滚动升级（Statefulset部署的特性）

有状态应用对应K8s工作负载是Statefulset。对于Statefulset，“**固定的网络标识符**”是通过Headless Service和集群DNS机制实现；而“**稳定的存储**”是通过PV/PVC/VolumeClaimTemplates等机制实现。

Statefulset具有上述特点，使其尤其适合用来部署存储类、集群类应用。例如：

- [MongoDB](https://kubernetes.io/blog/2017/01/running-mongodb-on-kubernetes-with-statefulsets)
- [zookeeper部署示例1](https://jimmysong.io/kubernetes-handbook/guide/using-statefulset.html)、[zookeeper部署示例
  2:Running ZooKeeper, A CP Distributed System](https://kubernetes.io/docs/tutorials/stateful-application/zookeeper/)
- [kafka](https://jimmysong.io/kubernetes-handbook/guide/using-statefulset.html)
- [Cassandra](https://kubernetes.io/docs/tutorials/stateful-application/cassandra/)
- [MySQL](https://kubernetes.io/docs/tasks/run-application/run-replicated-stateful-application/)
- [Redis](https://github.com/CommercialTribe/kube-redis)



### 1. Headless Service

Headless Service是一种特殊的K8s Service。从逻辑上，普通Service相当于反向代理，发给普通Service的流量会转发给Service后端的pod；而Headless Service仅提供类似DNS的功能，返回后端pod IP。

在YAML配置上，Headless Service与普通Service的区别在于，Headless Service的spec.clusterIP必须设置为``None``。

尝试创建如下Headless Service：

```
apiVersion: v1
kind: Service
metadata:
  annotations:
  labels:
    app: eureka
  name: eureka-headless #ping eureka-headless,提供DNS发现
  namespace: pg-allen-ali   #【修改为各自namespace】
spec:
  clusterIP: None #区别普通实例
  ports:
  - port: 8761
    protocol: TCP
    targetPort: 8761
  selector:
    app: eureka
  sessionAffinity: None
  type: ClusterIP
```

查看Headless Service信息：

```
# kubectl get svc eureka-headless -n pg-allen-ali
NAME              TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)    AGE
eureka-headless   ClusterIP   None         <none>        8761/TCP   150m
```



### 2. PV/PVC（PV的存储资源声明多少）

Kubernetes存储资源控制的核心是PV（PersistentVolume）与PVC（PersistentVolumeClaim）。可参考[Kubernetes官方PV、PVC的说明文档](https://kubernetes.io/docs/concepts/storage/persistent-volumes/) 来理解这两个概念。

PV是集群中与节点同级的资源，区别在于：节点是集群的计算资源，而PV是集群的存储资源。集群管理员预先部署好存储系统（例如NFS、CephFS等），然后定义一个PV即可将存储资源置于Kubernetes管理之下。

PVC与memory/cpu request有相似之处，区别在于：memory/cpu request是容器对计算资源需求的声明，而PVC是容器对存储资源需求的声明。

PV是集群层面的概念，与节点同级。PV属于集群，但不属于任何Namespace。 而PVC属于特定的Namespace，只能被同一个Namespace下的Pod所使用（可多个Pod共用一个PVC）。



### 3. Statefulset

创建如下statefulset

```
apiVersion: apps/v1 #pod之间的访问
kind: StatefulSet
metadata:
  labels:
    app: eureka
  name: eureka
  namespace: pg-allen-ali   #【修改为各自namespace】
spec:
  podManagementPolicy: Parallel #pod启动的一个策略，并行启动
  replicas: 2
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: eureka
  serviceName: eureka-headless    # headless service名，很重要
  template:
    metadata:
      labels:
        app: eureka
        project: k8s-playground
    spec:
      containers:
      - env:
        - name: EUREKA_CLIENT_REGISTERWITHEUREKA
          value: "true"
        - name: EUREKA_CLIENT_FETCHREGISTRY
          value: "true"
        - name: replicas
          value: "2"
        - name: EUREKA_NAMESPACE
          value: pg-allen-ali    # 【修改为各自namespace】
        image: registry-vpc.ap-southeast-1.aliyuncs.com/allen-mo/proj.k8s-playground_app.eureka:20191227_01
        imagePullPolicy: Always
        livenessProbe:
          failureThreshold: 3
          initialDelaySeconds: 168
          periodSeconds: 20
          successThreshold: 1
          tcpSocket:
            port: 8761
          timeoutSeconds: 1
        name: eureka
        readinessProbe:
          failureThreshold: 3
          httpGet:
            path: /actuator/health
            port: 8761
            scheme: HTTP
          initialDelaySeconds: 11
          periodSeconds: 20
          successThreshold: 1
          timeoutSeconds: 1
        resources:
          limits:
            cpu: 500m
            memory: 768Mi
          requests:
            cpu: 100m
            memory: 512Mi
        volumeMounts:     # volume挂载
        - mountPath: /dianyi/data
          name: eureka-data
      dnsPolicy: ClusterFirst
      restartPolicy: Always
  updateStrategy:
    rollingUpdate:
      partition: 0      # 滚动升级的分区：分批进行，先升级序号>partition，不分区
    type: RollingUpdate
  volumeClaimTemplates:       # 动态PV声明，两种，静态+动态升级
  - metadata:
      name: eureka-data
      namespace: pg-allen-ali
    spec:
      accessModes:
      - ReadWriteOnce #存储读写一次，aws
      - ReadOnlyMany #读多次
      - ReadWriteMany #写多次
      storageClassName: alicloud-nas
      resources:
        requests:
          storage: 1Gi #容量需求多大
      volumeMode: Filesystem
```

若statefulset的pod未能正常启动，则可查看statefulset状态：

```
# kubectl -n pg-allen-ali describe statefulset eureka
```

查看pod状态：

```
# kubectl -n pg-allen-ali get po
```



**查看PVC**

```
# kubectl -n pg-allen-ali get pvc
```

PVC状态是否为``Bound``状态？



**查看PV**

```
# kubectl get pv
```

PV状态是否为``Bound``状态？



为了在集群外访问eureka服务，我们可以再搞一个普通Service：

```
apiVersion: v1
kind: Service
metadata:
  annotations:
    service.beta.kubernetes.io/alicloud-loadbalancer-address-type: intranet
  labels:
    app: eureka
  name: eureka
  namespace: pg-allen-ali   #【改成各自Service】
spec:
  externalTrafficPolicy: Cluster
  ports:
  - port: 8761
    protocol: TCP
    targetPort: 8761
  selector:
    app: eureka
  sessionAffinity: None
  type: LoadBalancer
```

稍等片刻，即可通过SLB地址访问Eureka。



进入``eureka-0``这个pod：

```
# kubectl -n pg-allen-ali exec -it eureka-0 bash
# 查看挂载的volume
# df -h
Filesystem                                                                                                                    Size  Used Avail Use% Mounted on
7fcde4a719-bsa48.ap-southeast-1.nas.aliyuncs.com:/pg-allen-ali-eureka-data-eureka-0-pvc-6c4b31b9-7fa3-11ea-b7ec-00163e02d9d6   10P  166M   10P   1% /dianyi/data
... ...
# 往数据盘写个测试信息
# echo "in eureka-0" > /dianyi/data/data_test
# cat /dianyi/data/data_test
in eureka-0

# 尝试通过headless service访问另一个eureka实例
# ping eureka-1.eureka-headless
PING eureka-1.eureka-headless.pg-allen-ali.svc.cluster.local (172.20.27.72) 56(84) bytes of data.
64 bytes from 172-20-27-72.eureka.pg-allen-ali.svc.cluster.local (172.20.27.72): icmp_seq=1 ttl=62 time=1.03 ms
64 bytes from 172-20-27-72.eureka.pg-allen-ali.svc.cluster.local (172.20.27.72): icmp_seq=2 ttl=62 time=0.983 ms
^C
```

如有时间，还可进入``eureka-1``中执行类似的操作。






Next：[06-工作负载（3）-Daemonset](06-工作负载（3）-Daemonset.md)

# 工作负载（3）-Daemonset



Daemonset类应用会在集群所有节点上各运行1个pod（除非有其他调度限制）。

因其特点，Daemonset适用于部署如下类型应用：

* 采集类Agent，包括Flume、Fluented等。
* 运维监控类，包括Pormetheus Node-Exporter等。
* K8s自身组件，kube-proxy、K8s虚拟网络（如flannel、calico-node）、Cloud-controller-manager等。



### 1. Daemonset基础

**创建Daemonset**

```
apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
  labels:
    app: node-exporter
    project: k8s-playground
  name: node-exporter
  namespace: pg-allen  #修改为自己环境
spec:    # 没有replicas
  minReadySeconds: 30
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: node-exporter
  template:
    metadata:
      annotations:
        cluster-autoscaler.kubernetes.io/safe-to-evict: "true"
      creationTimestamp: null
      labels:
        app: node-exporter
        project: k8s-playground
    spec:
      automountServiceAccountToken: false
      containers:
      - env:
        - name: web_listen_address
          value: "19100"      #修改为自己端口
        image: 172.30.10.185:15000/common/prometheus-node-exporter:2020041501
        imagePullPolicy: Always
        livenessProbe:
          failureThreshold: 3
          initialDelaySeconds: 168
          periodSeconds: 20
          successThreshold: 1
          tcpSocket:
            port: 19100   #修改为自己端口
          timeoutSeconds: 1
        name: node-exporter
        readinessProbe:
          failureThreshold: 3
          initialDelaySeconds: 11
          periodSeconds: 20
          successThreshold: 1
          tcpSocket:
            port: 19100   #修改为自己端口
          timeoutSeconds: 1
        resources:
          limits:
            cpu: 400m
            memory: 256Mi
          requests:
            cpu: 50m
            memory: 50Mi
        volumeMounts:    # 通常以hostsPath方式挂载宿主机目录
        - mountPath: /host/proc
          name: volume0
        - mountPath: /host/sys
          name: volume1
      dnsPolicy: Default
      hostNetwork: true
      restartPolicy: Always
      volumes:
      - hostPath:
          path: /proc
          type: ""
        name: volume0
      - hostPath:
          path: /sys
          type: ""
        name: volume1
  templateGeneration: 1
  updateStrategy:   # 滚动升级策略
    rollingUpdate:
      maxUnavailable: 10     # maxUnavailable必须大于0
    type: RollingUpdate
```



访问：

```
# curl http://172.30.10.122:19100/metrics
... ...
```



查看：

```
# kubectl describe ds node-exporter -n pg-allen
... ...

# kubectl get ds node-exporter -n pg-allen
NAME            DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
node-exporter   55        55        54      55           54          <none>          2m48s

# kubectl get po -n pg-allen
... ...
```



删除daemonset：

```
# kubectl delete ds node-exporter -n pg-allen
daemonset.extensions "node-exporter" deleted
```



Next：[07-工作负载（4）-Job和Cronjob](07-工作负载（4）-Job和Cronjob.md)

# 工作负载（4）-Job和Cronjob

Job：批处理任务

Cronjob：定时批处理



创建Cronjob

```
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  creationTimestamp: null
  generateName: reload-prometheus
  namespace: 【pg-allen-job】
  name: reload-prometheus
  labels:
    app: reload-prometheus
spec:
  concurrencyPolicy: Replace    # 并发策略。默认值Replace。
  failedJobsHistoryLimit: 2      # 保留的失败记录数。为了减少资源消耗，不建议配置过大。
  schedule: '*/3 * * * *'   # 定时任务的crontab时间配置，按 <minute> <hour> <day of month> <month> <day of week>格式填写。
  startingDeadlineSeconds: 60   # job启动超时时间。
  successfulJobsHistoryLimit: 5   # 保留的成功记录数。为了减少资源消耗，不建议配置过大。
  suspend: false      # 若job未执行完毕，是否挂起后续job。默认值false。
  jobTemplate:
    spec:
      backoffLimit: 3    # 重启次数限制，重启达到次数后，则不再重启。
      template:
        metadata:
          labels:
            app: reload-prometheus
        spec:
          containers:
          - command:        # 定时执行的命令。需要确保命令在容器内能够正常执行。
            - curl
            args:
            - -X
            - PUT
            - --connect-timeout
            - "10"
            - -m
            - "60"
            - https://xxx.xxx.com/paas/ops/reload-prometheus
            image: 172.30.10.185:15000/common/curl-alpine:3.8
            imagePullPolicy: IfNotPresent
            name: reload-prometheus
            resources:
              limits:
                cpu: 800m
                memory: 100Mi
              requests:
                cpu: 100m
                memory: 10Mi
          dnsPolicy: Default
          hostNetwork: true
          restartPolicy: Never   # 重启策略。
```



等待数分钟，即可查看状态：

```
# kubectl get cronjob -n pg-allen-job
NAME                SCHEDULE      SUSPEND   ACTIVE   LAST SCHEDULE   AGE
reload-prometheus   */3 * * * *   False     0        39s             7m13s

# kubectl get job -n pg-allen-job
NAME                           COMPLETIONS   DURATION   AGE
reload-prometheus-1586920500   1/1           10s        40s

# kubectl get po -n pg-allen-job
NAME                                 READY   STATUS      RESTARTS   AGE
reload-prometheus-1586920500-2qg8b   0/1     Completed   0          48s

# kubectl logs -f reload-prometheus-1586920500-2qg8b -n pg-allen-job
... ...
```



研究完毕。删除创建的cronjob：

```
# kubectl delete cronjob reload-prometheus -n pg-allen-job --cascade=true
cronjob.batch "reload-prometheus" deleted
```

删除cronjob时，若添加``--cascade=true``，则会级联删除job和pod。



扩展阅读：

* CronJob：https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/
* Running Automated Tasks with a CronJob：https://kubernetes.io/docs/tasks/job/automated-tasks-with-cron-jobs/




