
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
