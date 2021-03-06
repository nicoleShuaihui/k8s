
### k8s 学习资源
http://www.servicemesher.com/istio-handbook

https://jimmysong.io/kubernetes-handbook/

k8s监控：https://www.kubernetes.org.cn/3418.html

日志收集EFK：https://www.kubernetes.org.cn/4278.html

https://istio.io/zh/docs/concepts/what-is-istio/

查看pods种内容：
```
kubectl get --help:查看你get的命令使用
-n:namespace
-o:--output='':json|yaml|wide|name|custom-columns=
 kubectl get pods -n tce -o yaml  ocloud-middleware-oapigw-api-56d9897894-n7xl7 
 ```

### 基于负载均衡的理解

二层负载均衡：基于MAC地址的二层负载均衡。

三层负载均衡：基于IP地址的负载均衡。

四层负载均衡：基于IP+端口的负载均衡。

七层负载均衡：基于URL等应用层信息的负载均衡。

### 七层

1、应用层（基于URL）
2、表示层
3、会话层（应用之间的通信会话，建立一个连接）
4、传输层(应用的地址，一个应用一个端口，故为TCP/IP协议)
5、网络层（物理虚机的虚机地址 ipv4,ipv6）
6、数据链路层 （表示一些mac地址，物理地址）
7、物理层（一些物理硬件）

### Master节点的服务

kube-apiserver: 部署在Master上暴露Kubernetes API，是Kubernetes的控制面。
etcd: 一致且高度可用的Key-Value存储，用作Kubernetes的所有群集数据的后备存储
kube-scheduler: 调度器，运行在Master上，用于监控节点中的容器运行情况，并挑选节点来创建新的容器。调度决策所考虑的因素包括资源需求，硬件/软件/策略约束，亲和和排斥性规范，数据位置，工作负载间干扰和最后期限。
kube-controller-manager：控制和管理器，运行在Master上，每个控制器都是独立的进程，但为了降低复杂性，这些控制器都被编译成单一的二进制文件，并以单独的进程运行。
### Node节点上面的服务:

kubelet: 运行在每一个 Node 节点上的客户端，负责Pod对应的容器创建，启动和停止等任务，同时和Master节点进行通信，实现集群管理的基本功能。
kube-proxy: 负责 Kubernetes Services的通信和负载均衡机制。
Docker Engine: 负责节点上的容器的创建和管理。

### [git常用命令](https://github.com/nicoleShuaihui/k8s/issues/3#issue-599400505)
### [k8s nodes 打标签](https://github.com/nicoleShuaihui/k8s/issues/4#issue-613039082)
### [k8s计算节点的下架与上架](https://github.com/nicoleShuaihui/k8s/issues/5#issue-613100341)
