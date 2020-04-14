## git工作流程概念


1.工作区：就是你在电脑里能看到的目录。

2.暂存区：英文叫stage, 或index。一般存放在 ".git目录下" 下的index文件（.git/index）中，所以我们把暂存区有时也叫作索引（index）。

3.版本库：工作区有一个隐藏目录.git，这个不算工作区，而是Git的版本库。



### 1、管理远程仓库：`git remote --help` 
 
 - 仓库添加：`git remote add 仓库名称 仓库连接`
 - 仓库删除：`git remote remove(rm) 仓库名称 `
 
 PS:可添加多个仓库名称
 
### 场景1：初始化仓库，本地添加远程仓库
```
git init 
git remote add origin  git@github.com:nicoleShuaihui/k8s.git
将内容放入节点中：git add .
touch README.md
创建一个节点：git commit -m "D"
git push origin master 
```
添加仓库的效果等于`git clone git@github.com:nicoleShuaihui/k8s.git`



### 2、分支操作
- 查看远程分支：` git branch -a`  
- 查看本地分支：`git branch `
- 创建test分支：`git branch test`，并推送分支 :`git push origin test`
- 切换test分支：`git checkout test`, 加强版--->创建并切换 `git checkout -b 分支名`
- 提交本地test分支作为远程的test分支：`git push origin test:test `
- 删除本地，远程分支：`git branch -d xxxxx，git branch -r -d origin/branch-name|( git push origin :xxxxx)`
- 合并分支：git merge dev(dev分支合并到master中)

### 3、版本操作
git操作本地的版本
```
1、git log --pretty=oneline :以一行显示提交日志信息
2、git reset --hard HEAD^:表示上一个版本/HEAD^^:表示上两个版本/HEAD~n:表示上n个版本/log_id
3、git reflog 查看命令历史，以便确定要回到未来的哪个版本
4、git reset 可以查看提交历史，以便确定要回退到哪个版本
5、git log --pretty=format:"%h - %an, %ar : %s" ：输出日志定制
说明：
  %H 提交对象（commit）的完整哈希字串
  %h 提交对象的简短哈希字串
  %T 树对象（tree）的完整哈希字串
  %t 树对象的简短哈希字串
  %P 父对象（parent）的完整哈希字串
  %p 父对象的简短哈希字串
  %an 作者（author）的名字
  %ae 作者的电子邮件地址
  %ad 作者修订日期（可以用 -date= 选项定制格式）
  %ar 作者修订日期，按多久以前的方式显示
  %cn 提交者(committer)的名字
  %ce 提交者的电子邮件地址
  %cd 提交日期
  %cr 提交日期，按多久以前的方式显示
  %s 提交说明
```

### 混淆命令说明

git fetch与git pull的区别
