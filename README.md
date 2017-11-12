# game_dev
基于skynet引擎的回合制游戏搭建

<br>这里我们介绍的是一种单服的游戏服务器结构，即我们在一台物理机上只运行一个服务器进程，所有的游戏内容都运行在此进程中
<br>影响服务器承载玩家上限的点主要有这么几点
<br>1.机器性能：主要在机器的主频，内存，cpu缓存上
<br>2.网络问题：带宽，IO读写
<br>3.游戏代码结构设计：单进程单线程的设计，所有的事务都需要等待上一条事务执行完毕才能开始处理
<br>4.游戏逻辑代码实现：游戏逻辑代码实现中需要注意编程语言的性能问题，以及一些玩法开发的耗时注意事项

<br>基于skynet的开发，我们将我们的游戏结构设计成一个单进程多线程的结构，对于比较耗时的服务，如场景，战斗，
<br>广播等一些功能我们可以另多开几条线程<lua虚拟机>去专门做这些处理，分散线程的压力。在此份代码中，可以看
<br>到在service下回出现war/scene/broadcast 等目录；这就是针对上述说表的具体实现

## 1.游戏代码目录结构
  <br>game_dev - 
  <br>           | - shell/     --存放常用的shell指令，如启动、关闭服务器等
  <br>           | - log/       --游戏日志输出
  <br>           | - service/   --游戏逻辑玩法服务
  <br>           | - config/    --游戏服务器基本配置信息
  <br>           | - skynet/    --skynet引擎源码以及执行文件
             
## 2.skynet引擎搭建
<br>           a.检出一份skynet源代码，地址：https://github.com/cloudwu/skynet.git
<br>           b.注意：skynet版本我只检出至c91efa513435e71f24fd869e15ef409e0caf6c86，往后有大修改，部分代码无法支持
<br>           c.编译skynet代码，期间会遇到一些库缺失的问题，安装完后编译即可
<br>
编译完成后,在skynet下我们会看到一份skynet/skynet的执行文件，skynet的启动流程可以通过
追踪skynet-src/skynet_main.c进行了解，在这里不在做具体的阐述。游戏的启动脚本我把他放
在了shell/gs_run.sh脚本下，通过执行该脚本我们可以将游戏服务器运行起来，当然你得先配置
好config/gs_config.lua文件，通过配置我们可以知道最终的启动工具是通过snlua bootstrap启
动bootstrap，然后通过bootstrap启动gs_launcher，gs_launcher.lua去启动游戏逻辑中需要的
各项服务内容

## 3.游戏后台搭建
<br> 游戏后台在这套框架中称之为dictator; dictator主要实现的是后台指令，区别游戏中的gm
指令,dictator主要用来实现在线更新,是否开放玩家登陆,关闭存盘等相关指令;每个服务的启动
都会向该服务注册一份各服务的地址信息，dictator做为一个指令的发起方，将指令根据地址传送
到各个服务上；根据这个机制可以实现各个服务代码的在线更新，启动这个服务后，我们会监听
本机器上的dictator_port端口(在config/gs_config.lua中配置)，通过nc localhost dictator_port
可以直连上后台，就可以输入相关的指令进行相关操作，如在线更新指令
update_code service/world/dictatorobj

与此同时，我们还启动了debug_console后台，用于监控各个服务的状态，相应代码位于
skynet/service/debug_console.lua下；

## 4.lua代码文件在线更新
<br> 参照云风博客：https://blog.codingnow.com/2008/03/hot_update.html
<br> 在这个系统中，载入一个文件我们使用了两种方式，一个是系统自带的require，另外一个是
自己实现的import；代码位于lualib/base/reload.lua下，这种划分相当于把文件按照能否在线更
新作为了标准；使用require的，我们默认认为此文件不能进行在线更新，使用import则是可以使用
lualib/base/reload.lua 下的reload文件进行在线更新
<br> 具体原理待阐述
在原生lua环境下，我们引用一个文件通常使用require，使用require后我们会把内容放置到package.loaded
下，如果我们要更新这个文件，首先我们会把package.loaded置控，然后重新require一次，但是这
种写法会使得一些地方无法更新到 如：local mod = require "mod"; 就算你重新require了一次，
这里的引用关系保持的还是旧的，除非我们把所有引用关系都遍历更新一次。而这个在线更新机制
在不解除旧有引用关系的前提下对内部数据进行了替换，详细实现参照代码：
lualib/base/reload.lua

## 5.关于多服务数据共享(sharedata)
<br> 在skynet中有一个叫做sharedatad的全局服务, 代码路径：skynet/lualib/sharedata.lua
支持new|query|update 三种方法；
sharedata.new(name, v, ...) 通过此方法可以创建一个新的sharedata数据块，v可以是字符串，table
sharedata.query(name) 通过此方法可以获得已经创建的sharedata数据块，但是我们发现实际美一次
query都会去创建一次新的table，实际上我们可以在上层的使用方法上去规避他
sharedata.update(name, v) 可以将名字为name的sharedata使用v进行一次更新

同时，在我的设想中，这个框架对于sharedata的数据应用应该只停留在读取游戏中的配置数据，一般来
讲只能是导表数据，停留在只读层面上， 我们不会去也不应该去改写sharedata上的数据，有数据需要
需要变动的时候，我们通过在线调用update的方式去更新这些数据

由上述分析可以知道，我们要实现这写功能，需要有一个专门的服务去启动sharedatad和在线更新
sharedata
同时还需要有个文件去做数据加载的功能，需要对query做一层封装，规避重复创建table问题,
把sharedata设置为只读

## 6.关于数据存储
<br> 在这套框架中，我们的数据库采用mongodb；没有特别的原因，只是刚好我在使用这个数据库而已，
想要使用mysql也是可以的。在使用mongodb的时候要注意规避内存OOM的问题，因为mongodb引擎采用的
是内存换效率的策略，如果不加已限制，则会导致机器的内存被完全耗尽。

skyent 封装了一套mongodb的lua接口，位于skyent/lualib/mongo.lua；这个框架的所有存储实现都基于
这个模块去做的实现。

根据skyent的单进程多线程模型，我们对整个游戏启动了一个专门处理数据存储的服务，叫做gamedb
在gamedb中，我们实现了一套适用于游戏存储的一套方法，位于：service/gamedb/gamedb.lua下
其他服务如果有存储的需求，都会通过actor模型，将需要存储的数据发送到gamedb服务下，去做存储
有效的去分担主线程的压力

在这套回合制游戏框架中，我们的存盘策略采用的是相对来说比较简单的策略，目前的想法只涉及到
[定时存盘]：对于容错率相对来说比较高的数据块，我们采用打脏标记，5分钟一次的存盘策略
[及时存盘]：对于容错率低的数据块，则我们采用的是即时存盘，比如玩家的ID分配等一些相关内容
[关联存盘]：对于数据关联性比较大的多个块，我们采用关联存盘，就算回档也会回到同一时间段，
比如玩家之间的交易行为

## 7.跨服务数据交互
<br> 在[5]中我们提到了要对共享数据进行在线更新，而共享数据也是单独的一个服务，我们怎么做到
在dictator后台对sharedatad服务的数据进行更新？在[6]中我们也提到了gamedb用于存储逻辑服务产生
的存盘数据，但是我们怎么将存盘块数据发送到gamedb中进行存储，需要的使用我们又怎么从gamedb中
获取到相关数据。这就是我们需要做跨服务数据交互通讯的理由。

在skynet中，我们每启动一个服务都会有个专门的标识，在log/gs.log中我们可以看到一串的十六进制
字符，这个其实就是每个服务的一个标识符，也可以说是每个服务的地址，我们通过这个地址在整个进
程中找到这个服务，与此同时我们在每启动一个服务的时候也会向skynet注册一个服务的别名。如在启
动gamedb的时候，我们有skynet.register(".gamedb")，只要注册了这个别名，我们也可以通过该别名
去访问相应的服务线程

在interactive中我们定义了另外通信协议PTYPE_LOGIC，专门用于游戏逻辑服务间的通讯，在每个服务
启动的时候我们需要调用interactive.dispatch_logic进行一次初始化

具体的代码实现在lualib/base/interactive.lua下。

## 8.客户端服务端协议交互(protobuf)
<br> CS之间的通讯我们引入protobuf，协议的解析我们采用云风写的pbc
首先我们需要在机器上安装一个protobuf，我采用的是直接检出git安装的，git地址：
git clone https://github.com/google/protobuf.git
在运行./autogen.sh 之前，我们还需要安装一些必要的内容，有unzip,autoconf,automake,libtool
<br> 1.执行 ./autogen.sh
<br> 2.执行 ./configure 执行过程中可能会遇到一些问题，通常是库缺失，自行安装即可
<br> 3.make
<br> 4.make check
<br> 5.make install

<br> 编译pbc的时候采用了一种比较取巧的方式，直接将pbc:https://github.com/cloudwu/pbc.git
下中我们所需要的文件放入到skynet下的pbc文件夹下，有makefile，src，pbc.h，将pbc/binding下
的pbc-lua53放到pbc下，然后通过改写skynet/Makefile文件直接进行编译导入,最终，我们的使用方
式和pbc/binding下介绍的一致,只是我们将protobuff.lua文件放到了game_dev/lualib/base下,这样
我们就可以直接require "base.protobuf" 使用它

<br> 在这个游戏框架中，我将协议放到了proto/下， proto/base.proto 用于放置各个协议通用数据
结构，proto/server/*.proto 下放置的是服务端下行协议，统一命名方式是GS2CXXXX， 
proto/client/*.proto 下放置的是客户端上行协议,统一命名方式是C2GSXXXX。通过shell/make_proto.sh
进行协议的编译，编译结果为proto/proto.pb文件
<br> 在游戏启动的时候，我们通过在lualib/base/preload中调用了netfind.Init进行了协议的初始化, 
这样我们就可以在游戏中使用protobuf.encode protobuf.decode进行协议的编码，解码操作。
<br> proto/netdefines.lua 的作用是定义了各个交互协议的协议号，我们在客服务端交互的时候需要将
每个协议的协议号打包进数据流，客户端和服务端使用同一套标准，在收包的时候通过解指定位置得到
协议名，然后可以使用protobuf.decode 进行相关解析操作，最终得到我们发送的数据, 相关内容位于：
lualib/base/net.lua 和 lualib/base/netfind.lua 两个文件下

## 9.收发包流程 以及模拟客户端操作
<br> 服务端在收到客户端模拟建立连接的时候, gate收到请求会生成一个固定格式的字符串并用PTYPE_TEXT
格式将msg发送给给注册进行来的watch_dog; 详见：skynet/service-src/service_gate.c的_report函数。
watch_dog 收到消息后可以解析出 ip，端口，fd等相关信息，并对这些信息进行保留，用以回发数据,
skynet 也支持了对协议处理设置代理，让协议数据的处理转发到另外的服务中去处理。我们在设置好代理
并建立了连接后，就可以开始了通信。目前我写了一个简单的交互例子，
<br> 服务端代码位于service/login下， 客户端代码位于tool/下
<br> 操作步骤：[1]-启动好服务器后，[2]-使用./shell/client.sh 启动客户端脚本

