Linux Debugging, Profiling, Tracing and Performance Analysis Training
Duration: 2 days
Audience: Engineers, SRE, System administrators, DevOps
Prerequisites: Basic Linux command line knowledge
Training Objectives
At the end of this training, participants will be able to:
- Diagnose performance and stability issues on Linux systems
- Identify CPU, memory, disk I/O and network bottlenecks
- Use the right debugging and profiling tools in production-like environments
- Apply a structured methodology to analyze complex incidents
Day 1 – Linux Debugging and System Analysis
1. Linux Internals for Debugging
- Processes and threads
- Scheduling basics
- User space vs kernel space
- System calls and signals
2. Debugging Running Applications
- Using strace to analyze system calls
- Using ltrace to inspect library calls
- Signal handling (SIGTERM, SIGSEGV, SIGKILL)
- Debugging hung or slow processes
3. Memory Analysis
- Understanding memory usage on Linux
- /proc filesystem overview
- Detecting memory leaks and abnormal consumption
- OOM Killer behavior
- Tools: free, vmstat, pmap
Hands-on Labs – Day 1
- Debugging an application that freezes
- Investigating a crash scenario
- Analyzing abnormal memory usage
Day 2 – Profiling, Tracing and Performance Investigation
4. CPU and Performance Analysis
- Understanding load average
- CPU states and context switches
- Tools: top, htop, mpstat, pidstat
5. Profiling with perf
- Introduction to profiling concepts
- Using perf to identify hot paths
- Interpreting profiling results
- Understanding performance overhead
6. Disk I/O and Filesystem Analysis
- Disk latency and throughput
- Tools: iostat, iotop
- Filesystem vs block device analysis
7. Introduction to Tracing and Network Analysis
- Tracing concepts and use cases
- Introduction to eBPF and bpftrace (conceptual)
- Network performance analysis
- Tools: ss, tcpdump, iftop
Hands-on Labs – Day 2
- CPU-bound application investigation
- Disk I/O bottleneck analysis
- End-to-end performance troubleshooting case study
Methodology and Best Practices
- Structured approach to incident analysis
- Choosing the right tool at the right level
- Performance analysis in production environments
- Limits and risks of debugging tools in live systems