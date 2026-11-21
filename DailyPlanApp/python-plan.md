# 一个月 Python 精通计划

> 给 Six · 30 天：2026-11-21（六）— 2026-12-20（日）
> 每天 2.5 小时，工作日 2.5 小时、周末 3 小时，总共 80 小时
> 保底版：每天 1.5 小时也能走完，总共 45 小时，只做每天的“核心动手任务”，跳过加分项
> 起点：你已经有 ShopCLI 和 BERT 项目，不是零基础学语法，而是重打地基、打通底层
> 目标：一个月后能独立写、读懂、改代码，直接进你原来两个月 AI 计划的 RAG 项目

## 这份计划和你原来 AI 计划的关系

不冲突。这个月就是把你原来两个月 AI 计划前两周的 Python 复习，升级成精通版。

做完这个月，直接进 RAG 项目会顺很多，因为你已经打通了：文件 / 数据结构 / 后端 / 网络 / 测试，RAG 要用的那一套你都亲手写过一遍。

## 先看透：计算机的世界逻辑（Day 1 就画出来，后面都挂回这张图）

```
硬件 CPU / 内存 / 磁盘
  ↓
操作系统：进程、线程、文件系统、网络
  ↓
Python 运行时：解释器、内存管理、GIL、垃圾回收
  ↓
应用：你的代码、库、框架、API、数据库
```

另外记住两条“一生”：

1. **一个程序从源码到运行的一生**：写代码 → 解释器读源码 → 编译成字节码 → 解释执行 → 申请内存 / 调用系统 → 输出结果 / 报错退出
2. **一次 HTTP 请求的一生**：浏览器 / 客户端发请求 → DNS / TCP / HTTP → 服务器收到 → 路由 → 处理逻辑 → 查数据库 → 返回 JSON → 客户端渲染

后面每个知识点，问自己一句：它挂在这张图的哪一层？挂不上，就说明还没真懂。

## 搜资料的 3 条方法（开头就定死）

1. **中文讲不清就换英文搜**：同一个词，先搜中文，讲不清立刻搜英文原词，别在一个视频里耗着。
2. **报错复制最后一行搜**：报错不要整段复制，只复制最后一行 `Error: ...` 去搜，Google / 官方文档优先。
3. **一个知识点只看一个视频就关掉写代码**：看懂就停，看两个小时视频不写代码等于没学。

能搜的地方：B站、Google、Python 官方文档（docs.python.org）。下面每天的搜索词都给了中英文，直接复制就能搜。

## 每天固定 5 项（每天都一样，不用再猜今天该看什么）

1. **学什么**：今天的 Python 知识点
2. **直接搜什么**：Python 点的中英文搜索词
3. **计算机逻辑搜什么**：底层点的中英文搜索词
4. **动手做什么**：今天必须亲手写出来的东西
5. **过关标准**：做到什么样算今天通过，没过就补，不要往后拖

## 每天 2.5 小时怎么分

- 40 分钟：学 Python 点 + 搜资料
- 30 分钟：学计算机逻辑点
- 60 分钟：动手做今天的任务（其中 30 分钟给复刻项目，30 分钟给力扣，见下节）
- 20 分钟：复盘 + 过关自测，报错记进 `mistakes.md`

周末 3 小时：多出的 30 分钟全部给当周的复刻项目。

保底 1.5 小时版：只做“动手做什么”里的核心任务 + 过关标准，两个“搜什么”只看第一个结果；力扣保底只做当天第 1 道 Easy。

## 力扣 LeetCode 每日刷题（这版补上，之前漏了）

规则：每天 1-2 道，30 分钟一道，超时就看题解、关掉重写一遍，不硬耗。搜 `LeetCode 1 Two Sum` 就能找到原题，中英文题名都给了。

| 天 | 力扣题 | 难度 | 对应今天学的点 |
|---|---|---|---|
| Day 1 | 1. Two Sum 两数之和 | Easy | list / dict 入门 |
| Day 2 | 704. Binary Search 二分查找 | Easy | 循环 + 边界 |
| Day 3 | 217. Contains Duplicate 存在重复元素 | Easy | dict / set |
| Day 4 | 20. Valid Parentheses 有效的括号 | Easy | 栈 |
| Day 5 | 125. Valid Palindrome 验证回文串 | Easy | 字符串 |
| Day 6 | 136. Single Number 只出现一次的数字 | Easy | 异或 / dict |
| Day 7 | 26. Remove Duplicates from Sorted Array 删除有序数组中的重复项 | Easy | list 原地操作 |
| Day 8 | 242. Valid Anagram 有效的字母异位词 | Easy | 哈希表 |
| Day 9 | 155. Min Stack 最小栈 | Medium | 栈 |
| Day 10 | 53. Maximum Subarray 最大子数组和 | Medium | 动态规划入门 |
| Day 11 | 206. Reverse Linked List 反转链表 | Easy | 链表 / 类 |
| Day 12 | 141. Linked List Cycle 环形链表 | Easy | 快慢指针 |
| Day 13 | 169. Majority Element 多数元素 | Easy | 哈希 / 投票 |
| Day 14 | 70. Climbing Stairs 爬楼梯 | Easy | 递归 / DP |
| Day 15 | 121. Best Time to Buy and Sell Stock 买卖股票的最佳时机 | Easy | 一次遍历 |
| Day 16 | 283. Move Zeroes 移动零 | Easy | 双指针 |
| Day 17 | 344. Reverse String 反转字符串 | Easy | 双指针 / 字符串 |
| Day 18 | 21. Merge Two Sorted Lists 合并两个有序链表 | Easy | 链表 |
| Day 19 | 104. Maximum Depth of Binary Tree 二叉树的最大深度 | Easy | 递归 / 树 |
| Day 20 | 226. Invert Binary Tree 翻转二叉树 | Easy | 递归 / 树 |
| Day 21 | 94. Binary Tree Inorder Traversal 二叉树的中序遍历 | Easy | 栈 / 树 |
| Day 22 | 35. Search Insert Position 搜索插入位置 | Easy | 二分查找 |
| Day 23 | 27. Remove Element 移除元素 | Easy | 双指针 |
| Day 24 | 14. Longest Common Prefix 最长公共前缀 | Easy | 字符串 |
| Day 25 | 9. Palindrome Number 回文数 | Easy | 数学 / 字符串 |
| Day 26 | 13. Roman to Integer 罗马数字转整数 | Easy | dict 映射 |
| Day 27 | 58. Length of Last Word 最后一个单词的长度 | Easy | 字符串 |
| Day 28 | 66. Plus One 加一 | Easy | 数组 |
| Day 29 | 88. Merge Sorted Array 合并两个有序数组 | Easy | 双指针 |
| Day 30 | 1 + 20 + 704 三道重做，不看题解 | Easy | 验收：三道都能独立写出来 |

总共 30 道新题 + Day 30 重做 3 道。第 2 周开始可以自己加一道 Medium，比如 15. Three Sum 三数之和、33. Search in Rotated Sorted Array 搜索旋转排序数组、102. Binary Tree Level Order Traversal 二叉树的层序遍历，想加就加在当天第二道。

过关标准（力扣）：Easy 能独立写出来、讲清思路和时间复杂度；Medium 能看懂题解后关掉重写一遍。

## 6 个复刻项目 + 最后独立项目（每个项目都按 4 步走）

**四步法：跑通 → 重写 → 改需求 → 讲清原理**

1. 跑通：先让别人的 / 参考实现能跑起来
2. 重写：关掉参考，自己从零重写一遍
3. 改需求：自己加一个原计划没有的功能
4. 讲清原理：能讲清它在上面那张总图的哪一层、为什么这样设计

| # | 复刻项目 | 在哪一周 | 核心能力 |
|---|---|---|---|
| 1 | 命令行书店 v2 / 记账工具 2.0，带文件持久化 + 测试 | 第 1 周 | 文件、函数、异常、模块 |
| 2 | 日志分析器 | 第 2 周 | 字符串、正则、字典统计、文件 |
| 3 | 迷你数据库：自己写索引 + 持久化 | 第 2 周 | dict / 哈希、索引、文件 |
| 4 | 小爬虫：抓取 + 数据清洗 + 存 CSV | 第 3-4 周 | requests、解析、异常、数据清洗 |
| 5 | FastAPI 书店接口：书店 + 待办 + 用户系统全后端 | 第 3 周 | FastAPI、SQLAlchemy、JWT、异步 |
| 6 | 自动化测试小框架 | 第 4 周 | pytest、断言、测试用例设计 |
| ★ | **最后独立综合项目，三选一（Day 27-29）** | 第 4 周 | 见文末三选一 |

## 和群里的 Codex / Claude 怎么配合

- **Claude（想 + 审）**：讲不明白的概念、拆任务、review 代码、讲报错原因
- **Codex（干）**：在你 Mac 上跑代码、装环境、跑测试、修报错
- 流程：你先自己写 → 跑不通找 Codex 修 → 修完找 Claude 讲明白为什么错、review 一遍
- 规则：一个任务只 @ 一个人；同一个 bug Codex 修两次还不行，转给 Claude 诊断

---

# 第 1 周：Python 内核 + 计算机底层（Day 1-7，11/21-11/27）

目标：变量、内存、函数调用栈、list / dict 底层、异常、文件，全部能讲清底层。

## Day 1 · 11/21（六）— 环境 + 变量 + 内存

- **学什么**：装好 Python 3 + VS Code，变量、数据类型、输入输出
- **直接搜什么**：`Python 变量 数据类型 入门` / `Python variables data types tutorial`
- **计算机逻辑搜什么**：`二进制 编码 ASCII Unicode` / `binary encoding ASCII Unicode explained`
- **动手做什么**：画出上面那张总图，贴在 notes 里；写一个自我介绍生成器，输入名字、年龄，打印一句话
- **过关标准**：能说清 `a = 1` 之后内存里发生了什么；程序能跑通

## Day 2 · 11/22（日）— if / 循环 + CPU

- **学什么**：if / else、for / while、break / continue
- **直接搜什么**：`Python if for while 循环` / `Python if else for loop tutorial`
- **计算机逻辑搜什么**：`CPU 是怎么执行指令的` / `how CPU executes instructions`
- **动手做什么**：猜数字游戏（1-100，提示大了 / 小了，统计次数，最多 7 次机会）
- **过关标准**：不用看教程，能自己写出带次数限制的猜数字

## Day 3 · 11/23（一）— list / dict + 内存栈堆

- **学什么**：list、dict 的增删改查、遍历
- **直接搜什么**：`Python list dict 增删改查` / `Python list dict tutorial`
- **计算机逻辑搜什么**：`内存 栈 堆 区别` / `stack vs heap memory explained`
- **动手做什么**：通讯录：能加人、查人、删人，数据存在 list + dict 里
- **过关标准**：能讲清 list 和 dict 在内存里大概是怎么存的，栈和堆各放什么

## Day 4 · 11/24（二）— 函数 + 调用栈

- **学什么**：函数、参数、返回值、作用域
- **直接搜什么**：`Python 函数 参数 返回值` / `Python functions arguments return`
- **计算机逻辑搜什么**：`函数调用栈 call stack` / `function call stack explained`
- **动手做什么**：把猜数字、计算器改写成函数；写一个会递归调用自己的小函数，打印调用过程
- **过关标准**：能画出一次函数调用时调用栈的变化

## Day 5 · 11/25（三）— 字符串 + 操作系统

- **学什么**：字符串方法、格式化输出、f-string
- **直接搜什么**：`Python 字符串方法 f-string` / `Python string methods f-string`
- **计算机逻辑搜什么**：`操作系统 是什么 进程 文件系统` / `operating system process file system explained`
- **动手做什么**：计算器：支持 + - * /，输入 `q` 退出，输出用 f-string 格式化
- **过关标准**：计算器不崩，能讲清操作系统在程序运行里管了什么

## Day 6 · 11/26（四）— 异常 + 文件

- **学什么**：try / except、常见报错、open / with 读写文件
- **直接搜什么**：`Python try except 异常处理` / `Python try except file open with`
- **计算机逻辑搜什么**：`程序 从源码到运行 字节码` / `Python source code to bytecode execution`
- **动手做什么**：给计算器加异常处理（除零、输字母都不崩）；把通讯录存进文件，重启程序数据还在
- **过关标准**：能说清一个程序从源码到运行经历了哪几步；文件版通讯录重启后数据不丢

## Day 7 · 11/27（五）— 第 1 周收尾：复刻项目 1

- **学什么**：模块、import、把代码拆成多个文件
- **直接搜什么**：`Python 模块 import 自己写模块` / `Python modules import tutorial`
- **计算机逻辑搜什么**：`Python 运行时 解释器` / `Python interpreter runtime explained`
- **动手做什么**：**复刻项目 1：命令行书店 v2 / 记账工具 2.0**——能加书 / 记账、查、删、存文件，拆成 `main.py + utils.py + data.json`，加 3 个简单测试
- **过关标准**：按四步法走完跑通、重写、改需求（自己加一个按日期统计功能）、讲清原理；能讲清它挂在总图的哪一层

---

# 第 2 周：数据结构、算法、面向对象（Day 8-14，11/28-12/04）

目标：list / dict / set、队列、栈、哈希表、排序、递归、类、继承、多态、设计模式，知道时间复杂度和 GIL、垃圾回收。

## Day 8 · 11/28（六）— list / dict / set 底层

- **学什么**：list、dict、set 的用法和区别
- **直接搜什么**：`Python list dict set 区别` / `Python list dict set difference`
- **计算机逻辑搜什么**：`哈希表 哈希冲突` / `hash table hash collision explained`
- **动手做什么**：用 dict 做一个词频统计，统计一段文字里每个词出现几次
- **过关标准**：能讲清 dict 为什么查得快，哈希冲突是什么意思

## Day 9 · 11/29（日）— 队列、栈 + 时间复杂度

- **学什么**：用 list / collections 实现队列、栈
- **直接搜什么**：`Python 队列 栈 collections deque` / `Python queue stack deque tutorial`
- **计算机逻辑搜什么**：`时间复杂度 大O` / `time complexity Big O explained`
- **动手做什么**：**复刻项目 2 开始：日志分析器**——读一个日志文件，按级别（INFO / ERROR）统计数量，输出最多的 10 条错误
- **过关标准**：日志分析器能跑通；能说清你的统计方法是 O(n) 还是 O(n²)

## Day 10 · 11/30（一）— 排序、递归

- **学什么**：排序、递归、sorted / sort 的 key 用法
- **直接搜什么**：`Python 排序 sorted key lambda` / `Python sorting recursion tutorial`
- **计算机逻辑搜什么**：`递归 调用栈 溢出` / `recursion call stack overflow`
- **动手做什么**：给日志分析器加排序：按出现次数排错误；写一个递归算阶乘 / 斐波那契，并算一下它有多慢
- **过关标准**：能讲清递归为什么会栈溢出，排序 key 是怎么用的

## Day 11 · 12/01（二）— 类和对象

- **学什么**：class、__init__、方法、实例属性
- **直接搜什么**：`Python 类 对象 __init__` / `Python class object init tutorial`
- **计算机逻辑搜什么**：`Python GIL 是什么` / `Python GIL explained`
- **动手做什么**：把通讯录 / 书店里的数据写成 `Book` / `Person` 类；**复刻项目 3 开始：迷你数据库**——先定数据模型，一个表就是一个类 + 一个 JSON 文件
- **过关标准**：能讲清类和 dict 各适合什么时候用；GIL 能用一句话讲清

## Day 12 · 12/02（三）— 继承、多态、设计模式

- **学什么**：继承、多态、简单设计模式（单例、工厂大概知道就行）
- **直接搜什么**：`Python 继承 多态` / `Python inheritance polymorphism tutorial`
- **计算机逻辑搜什么**：`垃圾回收 GC 引用计数` / `Python garbage collection reference counting`
- **动手做什么**：给迷你数据库加两种表：`BookTable` 和 `UserTable` 都继承同一个 `Table` 基类
- **过关标准**：能讲清继承解决了什么重复代码问题；能讲清 Python 垃圾回收大概怎么工作

## Day 13 · 12/03（四）— 索引 + 持久化

- **学什么**：JSON / CSV 读写、自己写索引
- **直接搜什么**：`Python JSON CSV 读写` / `Python json csv read write`
- **计算机逻辑搜什么**：`B树 数据库索引 为什么存在` / `B-tree database index explained`
- **动手做什么**：给迷你数据库加索引：按书名建一个 dict 索引，查书不用全表扫描；数据存文件，重启还在
- **过关标准**：能讲清 B 树和哈希为什么存在，索引查和全表扫差在哪

## Day 14 · 12/04（五）— 第 2 周收尾

- **学什么**：本周复习 + 把两个项目串起来
- **直接搜什么**：`Python 数据结构 面试题` / `Python data structures interview questions`
- **计算机逻辑搜什么**：`Python list dict 底层实现` / `Python list dict implementation CPython`
- **动手做什么**：日志分析器 + 迷你数据库各按四步法走完一遍：跑通、重写、改需求（日志分析器加按日期过滤，迷你数据库加删除 + 更新）、讲清原理
- **过关标准**：不用看教程，能重写出迷你数据库的核心增删改查 + 索引

---

# 第 3 周：工程化 + 后端 + 网络（Day 15-21，12/05-12/11）

目标：Git、pytest、虚拟环境、FastAPI、SQLAlchemy、JWT、异步，理解进程线程、TCP/IP、HTTP、数据库索引、缓存。

## Day 15 · 12/05（六）— Git + 虚拟环境

- **学什么**：Git 基础、虚拟环境 venv、pip、requirements.txt
- **直接搜什么**：`Git 入门 add commit push` / `Python venv 虚拟环境 pip` / `Python virtual environment venv tutorial`
- **计算机逻辑搜什么**：`进程 线程 区别` / `process vs thread explained`
- **动手做什么**：把前两周的项目放进 Git 仓库，建 venv，写 requirements.txt；给书店项目打第一个 tag
- **过关标准**：能独立建 venv、装包、提交代码；能讲清进程和线程的区别

## Day 16 · 12/06（日）— pytest + 测试思维

- **学什么**：pytest、断言、写测试用例
- **直接搜什么**：`pytest 入门 断言` / `pytest tutorial assert`
- **计算机逻辑搜什么**：`TCP IP HTTP 请求过程` / `TCP IP HTTP request process explained`
- **动手做什么**：给书店 v2 和迷你数据库各写 5 个 pytest 测试，跑通
- **过关标准**：`pytest` 能跑通，测试失败时能看懂是哪一个断言挂了

## Day 17 · 12/07（一）— requests + API

- **学什么**：requests、GET、看懂 JSON 返回
- **直接搜什么**：`Python requests GET JSON` / `Python requests tutorial JSON`
- **计算机逻辑搜什么**：`HTTP 请求 一生 DNS TCP` / `HTTP request lifecycle DNS TCP`
- **动手做什么**：天气查询：输入城市，打印今天天气（用免费天气 API），结果存成 JSON
- **过关标准**：能画出一次 HTTP 请求的一生；天气查询能跑通

## Day 18 · 12/08（二）— FastAPI 入门

- **学什么**：FastAPI、路由、请求 / 响应模型
- **直接搜什么**：`FastAPI 入门 路由` / `FastAPI tutorial routing`
- **计算机逻辑搜什么**：`REST API 设计` / `REST API design explained`
- **动手做什么**：**复刻项目 5 开始：FastAPI 书店接口**——先做 `GET /books` 和 `POST /books`，用内存 list 存数据
- **过关标准**：能用浏览器 / curl 调通两个接口；能讲清路由是干嘛的

## Day 19 · 12/09（三）— SQLAlchemy + 数据库

- **学什么**：SQLAlchemy、模型、增删改查落库
- **直接搜什么**：`SQLAlchemy 入门 模型` / `SQLAlchemy tutorial models`
- **计算机逻辑搜什么**：`数据库索引 缓存` / `database index cache explained`
- **动手做什么**：把 FastAPI 书店接口从内存 list 换成 SQLite + SQLAlchemy，重启数据不丢
- **过关标准**：重启服务后书还在；能讲清索引和缓存各是为了解决什么慢

## Day 20 · 12/10（四）— JWT + 用户系统

- **学什么**：JWT、登录、权限校验
- **直接搜什么**：`FastAPI JWT 登录` / `FastAPI JWT authentication tutorial`
- **计算机逻辑搜什么**：`JWT token 原理` / `JWT token how it works`
- **动手做什么**：给 FastAPI 加用户系统：注册、登录拿 token、没 token 不能加书；同时把待办清单也接进同一个后端
- **过关标准**：没 token 调写接口会被拦住；有 token 能正常写

## Day 21 · 12/11（五）— 异步 + 第 3 周收尾

- **学什么**：async / await、异步大概怎么工作
- **直接搜什么**：`Python async await 异步` / `Python async await tutorial`
- **计算机逻辑搜什么**：`异步 IO 事件循环` / `async IO event loop explained`
- **动手做什么**：FastAPI 书店接口按四步法走完：跑通、重写、改需求（加一个按作者搜索 + 分页）、讲清原理
- **过关标准**：能讲清同步和异步差在哪，什么时候该用异步

---

# 第 4 周：综合复刻 + 面试收尾（Day 22-30，12/12-12/20）

目标：爬虫 + 数据清洗、RAG 前置的文档问答 CLI、自动化测试框架，最后一天模拟面试和简历项目复盘。

## Day 22 · 12/12（六）— 爬虫入门

- **学什么**：requests + BeautifulSoup、解析 HTML
- **直接搜什么**：`Python 爬虫 BeautifulSoup` / `Python web scraping BeautifulSoup tutorial`
- **计算机逻辑搜什么**：`爬虫 robots 协议 合法` / `web scraping robots.txt legality`
- **动手做什么**：**复刻项目 4 开始：小爬虫**——抓一个公开页面的标题 / 列表，存 CSV；只抓公开页面，遵守 robots
- **过关标准**：能抓下来并存 CSV；能讲清爬虫要注意什么

## Day 23 · 12/13（日）— 数据清洗 + pandas

- **学什么**：pandas 读 CSV、筛选、分组统计、缺失值
- **直接搜什么**：`pandas 读 CSV 分组统计` / `pandas read csv groupby tutorial`
- **计算机逻辑搜什么**：`数据清洗 缺失值 去重` / `data cleaning missing values deduplication`
- **动手做什么**：用 pandas 清洗你抓到的数据：去重、补缺失值、按分类统计，输出一张表
- **过关标准**：清洗后的数据能讲出一个结论，不是只跑通代码

## Day 24 · 12/14（一）— matplotlib + 讲结论

- **学什么**：matplotlib 折线图、柱状图
- **直接搜什么**：`matplotlib 折线图 柱状图` / `matplotlib line bar chart tutorial`
- **计算机逻辑搜什么**：`数据可视化 讲故事` / `data visualization storytelling`
- **动手做什么**：给清洗后的数据 / 记账数据画一张图，并写三句话讲出结论；小爬虫按四步法走完
- **过关标准**：图能看懂，结论能讲清

## Day 25 · 12/15（二）— 自动化测试小框架

- **学什么**：把 pytest 用法抽象成自己的小框架：发现用例、运行、报告
- **直接搜什么**：`pytest 自定义 测试框架` / `build mini test framework Python`
- **计算机逻辑搜什么**：`测试金字塔 单元测试 集成测试` / `testing pyramid unit integration test`
- **动手做什么**：**复刻项目 6：自动化测试小框架**——能自动发现 `test_*.py`、跑用例、输出通过 / 失败清单；先给书店接口用上
- **过关标准**：框架能跑你前面项目的测试，并输出一份通过清单

## Day 26 · 12/16（三）— RAG 前置：文档问答 CLI

- **学什么**：读文件、分块、简单检索（先不用向量库，用关键词检索打底）
- **直接搜什么**：`Python 文档问答 RAG 前置` / `Python document QA CLI retrieval`
- **计算机逻辑搜什么**：`RAG 检索增强生成 原理` / `RAG retrieval augmented generation explained`
- **动手做什么**：写一个文档问答 CLI：读一个文件夹的 .md / .txt，切块、关键词检索、返回最相关的 3 段；这是你下个月 RAG 项目的前置版
- **过关标准**：问一个文档里有的问题，能返回相关段落；能讲清 RAG 是检索 + 生成两步

## Day 27 · 12/17（四）— 独立综合项目 Day 1：定题 + 搭架子

- **学什么**：独立拆任务、定数据模型、搭架子
- **直接搜什么**：`Python 项目 拆任务 架构` / `Python project structure planning`
- **计算机逻辑搜什么**：`把四周串成一张图 硬件到应用` / `computer system layers hardware to application`
- **动手做什么**：**最后独立综合项目，三选一，选定一个**（见下表），拆成 5-8 个小任务，搭架子、核心模型先跑通
- **过关标准**：任务清单列出来了，架子能跑起来

## Day 28 · 12/18（五）— 独立综合项目 Day 2：核心功能

- **学什么**：按清单实现核心功能 1-2 个
- **直接搜什么**：按你选的项目搜对应关键词，见三选一表
- **计算机逻辑搜什么**：`FastAPI + 数据库 + 爬虫 串起来` / `full stack Python project architecture`
- **动手做什么**：实现核心功能，数据落库 / 落文件
- **过关标准**：核心流程能从头跑到尾

## Day 29 · 12/19（六）— 独立综合项目 Day 3：加功能 + 重构

- **学什么**：自己加一个计划外的功能、重构、补测试、写 README
- **直接搜什么**：`Python 重构 删重复代码` / `Python refactoring tutorial`
- **计算机逻辑搜什么**：`README 怎么写 项目文档` / `how to write README project`
- **动手做什么**：加一个新功能；删重复代码、拆函数、补注释；给项目补 5 个测试；写 README（这项目是干嘛的、怎么跑）
- **过关标准**：README 照着跑能跑通；测试能跑通

## Day 30 · 12/20（日）— 验收 + 模拟面试

- **学什么**：复盘四周、模拟面试、简历项目复盘
- **直接搜什么**：`Python 面试题 基础` / `Python interview questions beginner`
- **计算机逻辑搜什么**：`从硬件到应用 讲一遍` / `explain computer from hardware to application`
- **动手做什么**：做下面 11 项验收清单；找 Claude 做一次模拟面试，讲一遍总图 + 讲一遍你最熟的两个项目
- **过关标准**：验收清单打勾 9 项算达成

### 最后独立综合项目，三选一

| 选项 | 做什么 | 搜什么 |
|---|---|---|
| A | **RAG 前置文档问答 CLI 完整版**：读文件夹、分块、检索、问答，留好接向量库 / 大模型的口子 | `Python RAG document QA CLI` / `RAG 前置 文档问答` |
| B | **爬虫 + 数据清洗 + 可视化**：定时抓公开数据、清洗、存库、出一张日报图 | `Python 爬虫 数据清洗 可视化 项目` / `Python scraping data cleaning visualization project` |
| C | **FastAPI 书店 + 用户完整后端**：在 Day 18-21 的基础上加搜索、分页、权限、测试全套 | `FastAPI 完整项目 书店 用户` / `FastAPI full project tutorial` |

选哪个都行，选 A 最顺，直接对接下个月 RAG。

---

## Day 30 · 11 项验收清单（打勾 9 项算达成）

- [ ] 1. 不用看教程，能重写命令行书店 v2 的核心增删改查 + 文件持久化
- [ ] 2. 能讲清 list / dict 底层、哈希冲突、时间复杂度
- [ ] 3. 迷你数据库能跑：增删改查 + 索引 + 重启数据不丢
- [ ] 4. FastAPI 书店接口能跑：注册 / 登录 / JWT / 增删改查都通
- [ ] 5. 小爬虫能抓公开页面、清洗、存 CSV，并讲出一个数据结论
- [ ] 6. 自动化测试小框架能跑前面项目的测试，并输出通过清单
- [ ] 7. 能画出总图，并讲清一个程序从源码到运行、一次 HTTP 请求的一生
- [ ] 8. 独立综合项目（A / B / C 三选一）能从头跑到尾，有 README
- [ ] 9. `mistakes.md` 里有至少 20 条报错记录，每条都能讲清为什么错
- [ ] 10. 模拟面试能讲清两个项目：它解决了什么、怎么设计的、如果重做会怎么改
- [ ] 11. 力扣 30 道都做过，Day 30 重做的 1 / 20 / 704 三道不用看题解就能写出来

## 如果某天断了怎么办

- 断 1 天：第二天先补前一天的“动手做什么”，再做当天的，不用两天全补
- 断 3 天以上：直接从断的那天继续，跳过已过期的“搜什么”，只补动手任务
- 周末是缓冲：12/19-12/20 本来就是收尾周末，前面欠的项目可以在这两天补

## 每日复盘模板（10 分钟）

- 今天学了什么（一句话）：
- 写了什么 / 做到哪一步：
- 报错 / 卡住的地方 + 最后怎么解决的：
- 明天先做什么：

---

*重新做的版本：按你发的三张截图合并——30 天 11/21-12/20、每天 2.5 小时 / 周末 3 小时 / 保底 1.5 小时、每天 1 个 Python 点 + 1 个计算机逻辑点 + 1 个动手任务、每天固定 5 项、6 个复刻项目 + 最后三选一、Day 30 验收。2026-11-21 补上力扣：每天 1 道、共 30 道新题 + Day 30 重做 3 道，验收清单从 10 项改成 11 项，打勾 9 项算达成。*
