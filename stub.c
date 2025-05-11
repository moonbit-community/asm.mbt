#include <dlfcn.h>
#include <string.h>
#include <sys/types.h>
#include <unistd.h>
#include <sys/mman.h>
#include <stdint.h>
#if defined(__linux__)
#include <sys/syscall.h>
#endif

// Allocate a memory region that can be written by MoonBit and later executed.
// This keeps the demo small, but production users should consider W^X policies
// and platform-specific cache-flushing requirements.
void* asm_dot_mbt_mmap(size_t length) {
    return mmap(NULL, length, PROT_READ | PROT_WRITE | PROT_EXEC, MAP_ANON | MAP_PRIVATE, -1, 0);
}

// Return a dynamic-loader handle for symbols already available in the process.
void* asm_dot_mbt_dlopen() {
    return dlopen(NULL, RTLD_LAZY | RTLD_GLOBAL);
}

#if defined(__linux__)
#define ASM_DOT_MBT_SYSCALL_MATCH(name, value) \
    if (strcmp(syscall_name, name) == 0) {     \
        return (int32_t)(value);               \
    }
#endif

// Look up Linux syscall numbers from the C library's compile-time SYS_* macros.
// Return -1 when the syscall is not known to this table or unavailable on the
// current target.
int32_t asm_dot_mbt_linux_syscall_number(const char* syscall_name) {
    if (syscall_name == NULL) {
        return -1;
    }
#if defined(__linux__)
#ifdef SYS_read
    ASM_DOT_MBT_SYSCALL_MATCH("read", SYS_read)
#endif
#ifdef SYS_write
    ASM_DOT_MBT_SYSCALL_MATCH("write", SYS_write)
#endif
#ifdef SYS_open
    ASM_DOT_MBT_SYSCALL_MATCH("open", SYS_open)
#endif
#ifdef SYS_close
    ASM_DOT_MBT_SYSCALL_MATCH("close", SYS_close)
#endif
#ifdef SYS_stat
    ASM_DOT_MBT_SYSCALL_MATCH("stat", SYS_stat)
#endif
#ifdef SYS_fstat
    ASM_DOT_MBT_SYSCALL_MATCH("fstat", SYS_fstat)
#endif
#ifdef SYS_lstat
    ASM_DOT_MBT_SYSCALL_MATCH("lstat", SYS_lstat)
#endif
#ifdef SYS_poll
    ASM_DOT_MBT_SYSCALL_MATCH("poll", SYS_poll)
#endif
#ifdef SYS_lseek
    ASM_DOT_MBT_SYSCALL_MATCH("lseek", SYS_lseek)
#endif
#ifdef SYS_mmap
    ASM_DOT_MBT_SYSCALL_MATCH("mmap", SYS_mmap)
#endif
#ifdef SYS_mprotect
    ASM_DOT_MBT_SYSCALL_MATCH("mprotect", SYS_mprotect)
#endif
#ifdef SYS_munmap
    ASM_DOT_MBT_SYSCALL_MATCH("munmap", SYS_munmap)
#endif
#ifdef SYS_brk
    ASM_DOT_MBT_SYSCALL_MATCH("brk", SYS_brk)
#endif
#ifdef SYS_ioctl
    ASM_DOT_MBT_SYSCALL_MATCH("ioctl", SYS_ioctl)
#endif
#ifdef SYS_pread64
    ASM_DOT_MBT_SYSCALL_MATCH("pread64", SYS_pread64)
#endif
#ifdef SYS_pwrite64
    ASM_DOT_MBT_SYSCALL_MATCH("pwrite64", SYS_pwrite64)
#endif
#ifdef SYS_readv
    ASM_DOT_MBT_SYSCALL_MATCH("readv", SYS_readv)
#endif
#ifdef SYS_writev
    ASM_DOT_MBT_SYSCALL_MATCH("writev", SYS_writev)
#endif
#ifdef SYS_access
    ASM_DOT_MBT_SYSCALL_MATCH("access", SYS_access)
#endif
#ifdef SYS_pipe
    ASM_DOT_MBT_SYSCALL_MATCH("pipe", SYS_pipe)
#endif
#ifdef SYS_select
    ASM_DOT_MBT_SYSCALL_MATCH("select", SYS_select)
#endif
#ifdef SYS_sched_yield
    ASM_DOT_MBT_SYSCALL_MATCH("sched_yield", SYS_sched_yield)
#endif
#ifdef SYS_mremap
    ASM_DOT_MBT_SYSCALL_MATCH("mremap", SYS_mremap)
#endif
#ifdef SYS_msync
    ASM_DOT_MBT_SYSCALL_MATCH("msync", SYS_msync)
#endif
#ifdef SYS_mincore
    ASM_DOT_MBT_SYSCALL_MATCH("mincore", SYS_mincore)
#endif
#ifdef SYS_madvise
    ASM_DOT_MBT_SYSCALL_MATCH("madvise", SYS_madvise)
#endif
#ifdef SYS_dup
    ASM_DOT_MBT_SYSCALL_MATCH("dup", SYS_dup)
#endif
#ifdef SYS_dup2
    ASM_DOT_MBT_SYSCALL_MATCH("dup2", SYS_dup2)
#endif
#ifdef SYS_pause
    ASM_DOT_MBT_SYSCALL_MATCH("pause", SYS_pause)
#endif
#ifdef SYS_nanosleep
    ASM_DOT_MBT_SYSCALL_MATCH("nanosleep", SYS_nanosleep)
#endif
#ifdef SYS_getitimer
    ASM_DOT_MBT_SYSCALL_MATCH("getitimer", SYS_getitimer)
#endif
#ifdef SYS_alarm
    ASM_DOT_MBT_SYSCALL_MATCH("alarm", SYS_alarm)
#endif
#ifdef SYS_setitimer
    ASM_DOT_MBT_SYSCALL_MATCH("setitimer", SYS_setitimer)
#endif
#ifdef SYS_getpid
    ASM_DOT_MBT_SYSCALL_MATCH("getpid", SYS_getpid)
#endif
#ifdef SYS_sendfile
    ASM_DOT_MBT_SYSCALL_MATCH("sendfile", SYS_sendfile)
#endif
#ifdef SYS_socket
    ASM_DOT_MBT_SYSCALL_MATCH("socket", SYS_socket)
#endif
#ifdef SYS_connect
    ASM_DOT_MBT_SYSCALL_MATCH("connect", SYS_connect)
#endif
#ifdef SYS_accept
    ASM_DOT_MBT_SYSCALL_MATCH("accept", SYS_accept)
#endif
#ifdef SYS_sendto
    ASM_DOT_MBT_SYSCALL_MATCH("sendto", SYS_sendto)
#endif
#ifdef SYS_recvfrom
    ASM_DOT_MBT_SYSCALL_MATCH("recvfrom", SYS_recvfrom)
#endif
#ifdef SYS_sendmsg
    ASM_DOT_MBT_SYSCALL_MATCH("sendmsg", SYS_sendmsg)
#endif
#ifdef SYS_recvmsg
    ASM_DOT_MBT_SYSCALL_MATCH("recvmsg", SYS_recvmsg)
#endif
#ifdef SYS_shutdown
    ASM_DOT_MBT_SYSCALL_MATCH("shutdown", SYS_shutdown)
#endif
#ifdef SYS_bind
    ASM_DOT_MBT_SYSCALL_MATCH("bind", SYS_bind)
#endif
#ifdef SYS_listen
    ASM_DOT_MBT_SYSCALL_MATCH("listen", SYS_listen)
#endif
#ifdef SYS_getsockname
    ASM_DOT_MBT_SYSCALL_MATCH("getsockname", SYS_getsockname)
#endif
#ifdef SYS_getpeername
    ASM_DOT_MBT_SYSCALL_MATCH("getpeername", SYS_getpeername)
#endif
#ifdef SYS_socketpair
    ASM_DOT_MBT_SYSCALL_MATCH("socketpair", SYS_socketpair)
#endif
#ifdef SYS_clone
    ASM_DOT_MBT_SYSCALL_MATCH("clone", SYS_clone)
#endif
#ifdef SYS_fork
    ASM_DOT_MBT_SYSCALL_MATCH("fork", SYS_fork)
#endif
#ifdef SYS_vfork
    ASM_DOT_MBT_SYSCALL_MATCH("vfork", SYS_vfork)
#endif
#ifdef SYS_execve
    ASM_DOT_MBT_SYSCALL_MATCH("execve", SYS_execve)
#endif
#ifdef SYS_exit
    ASM_DOT_MBT_SYSCALL_MATCH("exit", SYS_exit)
#endif
#ifdef SYS_wait4
    ASM_DOT_MBT_SYSCALL_MATCH("wait4", SYS_wait4)
#endif
#ifdef SYS_kill
    ASM_DOT_MBT_SYSCALL_MATCH("kill", SYS_kill)
#endif
#ifdef SYS_uname
    ASM_DOT_MBT_SYSCALL_MATCH("uname", SYS_uname)
#endif
#ifdef SYS_fcntl
    ASM_DOT_MBT_SYSCALL_MATCH("fcntl", SYS_fcntl)
#endif
#ifdef SYS_fsync
    ASM_DOT_MBT_SYSCALL_MATCH("fsync", SYS_fsync)
#endif
#ifdef SYS_fdatasync
    ASM_DOT_MBT_SYSCALL_MATCH("fdatasync", SYS_fdatasync)
#endif
#ifdef SYS_truncate
    ASM_DOT_MBT_SYSCALL_MATCH("truncate", SYS_truncate)
#endif
#ifdef SYS_ftruncate
    ASM_DOT_MBT_SYSCALL_MATCH("ftruncate", SYS_ftruncate)
#endif
#ifdef SYS_getdents
    ASM_DOT_MBT_SYSCALL_MATCH("getdents", SYS_getdents)
#endif
#ifdef SYS_getcwd
    ASM_DOT_MBT_SYSCALL_MATCH("getcwd", SYS_getcwd)
#endif
#ifdef SYS_chdir
    ASM_DOT_MBT_SYSCALL_MATCH("chdir", SYS_chdir)
#endif
#ifdef SYS_fchdir
    ASM_DOT_MBT_SYSCALL_MATCH("fchdir", SYS_fchdir)
#endif
#ifdef SYS_rename
    ASM_DOT_MBT_SYSCALL_MATCH("rename", SYS_rename)
#endif
#ifdef SYS_mkdir
    ASM_DOT_MBT_SYSCALL_MATCH("mkdir", SYS_mkdir)
#endif
#ifdef SYS_rmdir
    ASM_DOT_MBT_SYSCALL_MATCH("rmdir", SYS_rmdir)
#endif
#ifdef SYS_creat
    ASM_DOT_MBT_SYSCALL_MATCH("creat", SYS_creat)
#endif
#ifdef SYS_link
    ASM_DOT_MBT_SYSCALL_MATCH("link", SYS_link)
#endif
#ifdef SYS_unlink
    ASM_DOT_MBT_SYSCALL_MATCH("unlink", SYS_unlink)
#endif
#ifdef SYS_symlink
    ASM_DOT_MBT_SYSCALL_MATCH("symlink", SYS_symlink)
#endif
#ifdef SYS_readlink
    ASM_DOT_MBT_SYSCALL_MATCH("readlink", SYS_readlink)
#endif
#ifdef SYS_chmod
    ASM_DOT_MBT_SYSCALL_MATCH("chmod", SYS_chmod)
#endif
#ifdef SYS_fchmod
    ASM_DOT_MBT_SYSCALL_MATCH("fchmod", SYS_fchmod)
#endif
#ifdef SYS_chown
    ASM_DOT_MBT_SYSCALL_MATCH("chown", SYS_chown)
#endif
#ifdef SYS_fchown
    ASM_DOT_MBT_SYSCALL_MATCH("fchown", SYS_fchown)
#endif
#ifdef SYS_lchown
    ASM_DOT_MBT_SYSCALL_MATCH("lchown", SYS_lchown)
#endif
#ifdef SYS_umask
    ASM_DOT_MBT_SYSCALL_MATCH("umask", SYS_umask)
#endif
#ifdef SYS_gettimeofday
    ASM_DOT_MBT_SYSCALL_MATCH("gettimeofday", SYS_gettimeofday)
#endif
#ifdef SYS_getrlimit
    ASM_DOT_MBT_SYSCALL_MATCH("getrlimit", SYS_getrlimit)
#endif
#ifdef SYS_getrusage
    ASM_DOT_MBT_SYSCALL_MATCH("getrusage", SYS_getrusage)
#endif
#ifdef SYS_sysinfo
    ASM_DOT_MBT_SYSCALL_MATCH("sysinfo", SYS_sysinfo)
#endif
#ifdef SYS_times
    ASM_DOT_MBT_SYSCALL_MATCH("times", SYS_times)
#endif
#ifdef SYS_getuid
    ASM_DOT_MBT_SYSCALL_MATCH("getuid", SYS_getuid)
#endif
#ifdef SYS_getgid
    ASM_DOT_MBT_SYSCALL_MATCH("getgid", SYS_getgid)
#endif
#ifdef SYS_setuid
    ASM_DOT_MBT_SYSCALL_MATCH("setuid", SYS_setuid)
#endif
#ifdef SYS_setgid
    ASM_DOT_MBT_SYSCALL_MATCH("setgid", SYS_setgid)
#endif
#ifdef SYS_geteuid
    ASM_DOT_MBT_SYSCALL_MATCH("geteuid", SYS_geteuid)
#endif
#ifdef SYS_getegid
    ASM_DOT_MBT_SYSCALL_MATCH("getegid", SYS_getegid)
#endif
#ifdef SYS_getppid
    ASM_DOT_MBT_SYSCALL_MATCH("getppid", SYS_getppid)
#endif
#ifdef SYS_getpgrp
    ASM_DOT_MBT_SYSCALL_MATCH("getpgrp", SYS_getpgrp)
#endif
#ifdef SYS_setsid
    ASM_DOT_MBT_SYSCALL_MATCH("setsid", SYS_setsid)
#endif
#ifdef SYS_setreuid
    ASM_DOT_MBT_SYSCALL_MATCH("setreuid", SYS_setreuid)
#endif
#ifdef SYS_setregid
    ASM_DOT_MBT_SYSCALL_MATCH("setregid", SYS_setregid)
#endif
#ifdef SYS_getgroups
    ASM_DOT_MBT_SYSCALL_MATCH("getgroups", SYS_getgroups)
#endif
#ifdef SYS_setgroups
    ASM_DOT_MBT_SYSCALL_MATCH("setgroups", SYS_setgroups)
#endif
#ifdef SYS_setresuid
    ASM_DOT_MBT_SYSCALL_MATCH("setresuid", SYS_setresuid)
#endif
#ifdef SYS_getresuid
    ASM_DOT_MBT_SYSCALL_MATCH("getresuid", SYS_getresuid)
#endif
#ifdef SYS_setresgid
    ASM_DOT_MBT_SYSCALL_MATCH("setresgid", SYS_setresgid)
#endif
#ifdef SYS_getresgid
    ASM_DOT_MBT_SYSCALL_MATCH("getresgid", SYS_getresgid)
#endif
#ifdef SYS_getpgid
    ASM_DOT_MBT_SYSCALL_MATCH("getpgid", SYS_getpgid)
#endif
#ifdef SYS_setfsuid
    ASM_DOT_MBT_SYSCALL_MATCH("setfsuid", SYS_setfsuid)
#endif
#ifdef SYS_setfsgid
    ASM_DOT_MBT_SYSCALL_MATCH("setfsgid", SYS_setfsgid)
#endif
#ifdef SYS_getsid
    ASM_DOT_MBT_SYSCALL_MATCH("getsid", SYS_getsid)
#endif
#ifdef SYS_capget
    ASM_DOT_MBT_SYSCALL_MATCH("capget", SYS_capget)
#endif
#ifdef SYS_capset
    ASM_DOT_MBT_SYSCALL_MATCH("capset", SYS_capset)
#endif
#ifdef SYS_rt_sigaction
    ASM_DOT_MBT_SYSCALL_MATCH("rt_sigaction", SYS_rt_sigaction)
#endif
#ifdef SYS_rt_sigprocmask
    ASM_DOT_MBT_SYSCALL_MATCH("rt_sigprocmask", SYS_rt_sigprocmask)
#endif
#ifdef SYS_rt_sigpending
    ASM_DOT_MBT_SYSCALL_MATCH("rt_sigpending", SYS_rt_sigpending)
#endif
#ifdef SYS_rt_sigtimedwait
    ASM_DOT_MBT_SYSCALL_MATCH("rt_sigtimedwait", SYS_rt_sigtimedwait)
#endif
#ifdef SYS_rt_sigqueueinfo
    ASM_DOT_MBT_SYSCALL_MATCH("rt_sigqueueinfo", SYS_rt_sigqueueinfo)
#endif
#ifdef SYS_rt_sigsuspend
    ASM_DOT_MBT_SYSCALL_MATCH("rt_sigsuspend", SYS_rt_sigsuspend)
#endif
#ifdef SYS_sigaltstack
    ASM_DOT_MBT_SYSCALL_MATCH("sigaltstack", SYS_sigaltstack)
#endif
#ifdef SYS_utime
    ASM_DOT_MBT_SYSCALL_MATCH("utime", SYS_utime)
#endif
#ifdef SYS_mknod
    ASM_DOT_MBT_SYSCALL_MATCH("mknod", SYS_mknod)
#endif
#ifdef SYS_personality
    ASM_DOT_MBT_SYSCALL_MATCH("personality", SYS_personality)
#endif
#ifdef SYS_ustat
    ASM_DOT_MBT_SYSCALL_MATCH("ustat", SYS_ustat)
#endif
#ifdef SYS_statfs
    ASM_DOT_MBT_SYSCALL_MATCH("statfs", SYS_statfs)
#endif
#ifdef SYS_fstatfs
    ASM_DOT_MBT_SYSCALL_MATCH("fstatfs", SYS_fstatfs)
#endif
#ifdef SYS_sysfs
    ASM_DOT_MBT_SYSCALL_MATCH("sysfs", SYS_sysfs)
#endif
#ifdef SYS_getpriority
    ASM_DOT_MBT_SYSCALL_MATCH("getpriority", SYS_getpriority)
#endif
#ifdef SYS_setpriority
    ASM_DOT_MBT_SYSCALL_MATCH("setpriority", SYS_setpriority)
#endif
#ifdef SYS_sched_setparam
    ASM_DOT_MBT_SYSCALL_MATCH("sched_setparam", SYS_sched_setparam)
#endif
#ifdef SYS_sched_getparam
    ASM_DOT_MBT_SYSCALL_MATCH("sched_getparam", SYS_sched_getparam)
#endif
#ifdef SYS_sched_setscheduler
    ASM_DOT_MBT_SYSCALL_MATCH("sched_setscheduler", SYS_sched_setscheduler)
#endif
#ifdef SYS_sched_getscheduler
    ASM_DOT_MBT_SYSCALL_MATCH("sched_getscheduler", SYS_sched_getscheduler)
#endif
#ifdef SYS_sched_get_priority_max
    ASM_DOT_MBT_SYSCALL_MATCH("sched_get_priority_max", SYS_sched_get_priority_max)
#endif
#ifdef SYS_sched_get_priority_min
    ASM_DOT_MBT_SYSCALL_MATCH("sched_get_priority_min", SYS_sched_get_priority_min)
#endif
#ifdef SYS_sched_rr_get_interval
    ASM_DOT_MBT_SYSCALL_MATCH("sched_rr_get_interval", SYS_sched_rr_get_interval)
#endif
#ifdef SYS_mlock
    ASM_DOT_MBT_SYSCALL_MATCH("mlock", SYS_mlock)
#endif
#ifdef SYS_munlock
    ASM_DOT_MBT_SYSCALL_MATCH("munlock", SYS_munlock)
#endif
#ifdef SYS_mlockall
    ASM_DOT_MBT_SYSCALL_MATCH("mlockall", SYS_mlockall)
#endif
#ifdef SYS_munlockall
    ASM_DOT_MBT_SYSCALL_MATCH("munlockall", SYS_munlockall)
#endif
#ifdef SYS_vhangup
    ASM_DOT_MBT_SYSCALL_MATCH("vhangup", SYS_vhangup)
#endif
#ifdef SYS_pivot_root
    ASM_DOT_MBT_SYSCALL_MATCH("pivot_root", SYS_pivot_root)
#endif
#ifdef SYS_prctl
    ASM_DOT_MBT_SYSCALL_MATCH("prctl", SYS_prctl)
#endif
#ifdef SYS_arch_prctl
    ASM_DOT_MBT_SYSCALL_MATCH("arch_prctl", SYS_arch_prctl)
#endif
#ifdef SYS_adjtimex
    ASM_DOT_MBT_SYSCALL_MATCH("adjtimex", SYS_adjtimex)
#endif
#ifdef SYS_setrlimit
    ASM_DOT_MBT_SYSCALL_MATCH("setrlimit", SYS_setrlimit)
#endif
#ifdef SYS_chroot
    ASM_DOT_MBT_SYSCALL_MATCH("chroot", SYS_chroot)
#endif
#ifdef SYS_sync
    ASM_DOT_MBT_SYSCALL_MATCH("sync", SYS_sync)
#endif
#ifdef SYS_acct
    ASM_DOT_MBT_SYSCALL_MATCH("acct", SYS_acct)
#endif
#ifdef SYS_settimeofday
    ASM_DOT_MBT_SYSCALL_MATCH("settimeofday", SYS_settimeofday)
#endif
#ifdef SYS_mount
    ASM_DOT_MBT_SYSCALL_MATCH("mount", SYS_mount)
#endif
#ifdef SYS_umount2
    ASM_DOT_MBT_SYSCALL_MATCH("umount2", SYS_umount2)
#endif
#ifdef SYS_swapon
    ASM_DOT_MBT_SYSCALL_MATCH("swapon", SYS_swapon)
#endif
#ifdef SYS_swapoff
    ASM_DOT_MBT_SYSCALL_MATCH("swapoff", SYS_swapoff)
#endif
#ifdef SYS_reboot
    ASM_DOT_MBT_SYSCALL_MATCH("reboot", SYS_reboot)
#endif
#ifdef SYS_sethostname
    ASM_DOT_MBT_SYSCALL_MATCH("sethostname", SYS_sethostname)
#endif
#ifdef SYS_setdomainname
    ASM_DOT_MBT_SYSCALL_MATCH("setdomainname", SYS_setdomainname)
#endif
#ifdef SYS_iopl
    ASM_DOT_MBT_SYSCALL_MATCH("iopl", SYS_iopl)
#endif
#ifdef SYS_ioperm
    ASM_DOT_MBT_SYSCALL_MATCH("ioperm", SYS_ioperm)
#endif
#ifdef SYS_init_module
    ASM_DOT_MBT_SYSCALL_MATCH("init_module", SYS_init_module)
#endif
#ifdef SYS_delete_module
    ASM_DOT_MBT_SYSCALL_MATCH("delete_module", SYS_delete_module)
#endif
#ifdef SYS_quotactl
    ASM_DOT_MBT_SYSCALL_MATCH("quotactl", SYS_quotactl)
#endif
#ifdef SYS_gettid
    ASM_DOT_MBT_SYSCALL_MATCH("gettid", SYS_gettid)
#endif
#ifdef SYS_readahead
    ASM_DOT_MBT_SYSCALL_MATCH("readahead", SYS_readahead)
#endif
#ifdef SYS_setxattr
    ASM_DOT_MBT_SYSCALL_MATCH("setxattr", SYS_setxattr)
#endif
#ifdef SYS_lsetxattr
    ASM_DOT_MBT_SYSCALL_MATCH("lsetxattr", SYS_lsetxattr)
#endif
#ifdef SYS_fsetxattr
    ASM_DOT_MBT_SYSCALL_MATCH("fsetxattr", SYS_fsetxattr)
#endif
#ifdef SYS_getxattr
    ASM_DOT_MBT_SYSCALL_MATCH("getxattr", SYS_getxattr)
#endif
#ifdef SYS_lgetxattr
    ASM_DOT_MBT_SYSCALL_MATCH("lgetxattr", SYS_lgetxattr)
#endif
#ifdef SYS_fgetxattr
    ASM_DOT_MBT_SYSCALL_MATCH("fgetxattr", SYS_fgetxattr)
#endif
#ifdef SYS_listxattr
    ASM_DOT_MBT_SYSCALL_MATCH("listxattr", SYS_listxattr)
#endif
#ifdef SYS_llistxattr
    ASM_DOT_MBT_SYSCALL_MATCH("llistxattr", SYS_llistxattr)
#endif
#ifdef SYS_flistxattr
    ASM_DOT_MBT_SYSCALL_MATCH("flistxattr", SYS_flistxattr)
#endif
#ifdef SYS_removexattr
    ASM_DOT_MBT_SYSCALL_MATCH("removexattr", SYS_removexattr)
#endif
#ifdef SYS_lremovexattr
    ASM_DOT_MBT_SYSCALL_MATCH("lremovexattr", SYS_lremovexattr)
#endif
#ifdef SYS_fremovexattr
    ASM_DOT_MBT_SYSCALL_MATCH("fremovexattr", SYS_fremovexattr)
#endif
#ifdef SYS_tkill
    ASM_DOT_MBT_SYSCALL_MATCH("tkill", SYS_tkill)
#endif
#ifdef SYS_time
    ASM_DOT_MBT_SYSCALL_MATCH("time", SYS_time)
#endif
#ifdef SYS_futex
    ASM_DOT_MBT_SYSCALL_MATCH("futex", SYS_futex)
#endif
#ifdef SYS_sched_setaffinity
    ASM_DOT_MBT_SYSCALL_MATCH("sched_setaffinity", SYS_sched_setaffinity)
#endif
#ifdef SYS_sched_getaffinity
    ASM_DOT_MBT_SYSCALL_MATCH("sched_getaffinity", SYS_sched_getaffinity)
#endif
#ifdef SYS_io_setup
    ASM_DOT_MBT_SYSCALL_MATCH("io_setup", SYS_io_setup)
#endif
#ifdef SYS_io_destroy
    ASM_DOT_MBT_SYSCALL_MATCH("io_destroy", SYS_io_destroy)
#endif
#ifdef SYS_io_getevents
    ASM_DOT_MBT_SYSCALL_MATCH("io_getevents", SYS_io_getevents)
#endif
#ifdef SYS_io_submit
    ASM_DOT_MBT_SYSCALL_MATCH("io_submit", SYS_io_submit)
#endif
#ifdef SYS_io_cancel
    ASM_DOT_MBT_SYSCALL_MATCH("io_cancel", SYS_io_cancel)
#endif
#ifdef SYS_lookup_dcookie
    ASM_DOT_MBT_SYSCALL_MATCH("lookup_dcookie", SYS_lookup_dcookie)
#endif
#ifdef SYS_epoll_create
    ASM_DOT_MBT_SYSCALL_MATCH("epoll_create", SYS_epoll_create)
#endif
#ifdef SYS_remap_file_pages
    ASM_DOT_MBT_SYSCALL_MATCH("remap_file_pages", SYS_remap_file_pages)
#endif
#ifdef SYS_getdents64
    ASM_DOT_MBT_SYSCALL_MATCH("getdents64", SYS_getdents64)
#endif
#ifdef SYS_set_tid_address
    ASM_DOT_MBT_SYSCALL_MATCH("set_tid_address", SYS_set_tid_address)
#endif
#ifdef SYS_restart_syscall
    ASM_DOT_MBT_SYSCALL_MATCH("restart_syscall", SYS_restart_syscall)
#endif
#ifdef SYS_semtimedop
    ASM_DOT_MBT_SYSCALL_MATCH("semtimedop", SYS_semtimedop)
#endif
#ifdef SYS_fadvise64
    ASM_DOT_MBT_SYSCALL_MATCH("fadvise64", SYS_fadvise64)
#endif
#ifdef SYS_timer_create
    ASM_DOT_MBT_SYSCALL_MATCH("timer_create", SYS_timer_create)
#endif
#ifdef SYS_timer_settime
    ASM_DOT_MBT_SYSCALL_MATCH("timer_settime", SYS_timer_settime)
#endif
#ifdef SYS_timer_gettime
    ASM_DOT_MBT_SYSCALL_MATCH("timer_gettime", SYS_timer_gettime)
#endif
#ifdef SYS_timer_getoverrun
    ASM_DOT_MBT_SYSCALL_MATCH("timer_getoverrun", SYS_timer_getoverrun)
#endif
#ifdef SYS_timer_delete
    ASM_DOT_MBT_SYSCALL_MATCH("timer_delete", SYS_timer_delete)
#endif
#ifdef SYS_clock_settime
    ASM_DOT_MBT_SYSCALL_MATCH("clock_settime", SYS_clock_settime)
#endif
#ifdef SYS_clock_gettime
    ASM_DOT_MBT_SYSCALL_MATCH("clock_gettime", SYS_clock_gettime)
#endif
#ifdef SYS_clock_getres
    ASM_DOT_MBT_SYSCALL_MATCH("clock_getres", SYS_clock_getres)
#endif
#ifdef SYS_clock_nanosleep
    ASM_DOT_MBT_SYSCALL_MATCH("clock_nanosleep", SYS_clock_nanosleep)
#endif
#ifdef SYS_exit_group
    ASM_DOT_MBT_SYSCALL_MATCH("exit_group", SYS_exit_group)
#endif
#ifdef SYS_epoll_wait
    ASM_DOT_MBT_SYSCALL_MATCH("epoll_wait", SYS_epoll_wait)
#endif
#ifdef SYS_epoll_ctl
    ASM_DOT_MBT_SYSCALL_MATCH("epoll_ctl", SYS_epoll_ctl)
#endif
#ifdef SYS_tgkill
    ASM_DOT_MBT_SYSCALL_MATCH("tgkill", SYS_tgkill)
#endif
#ifdef SYS_utimes
    ASM_DOT_MBT_SYSCALL_MATCH("utimes", SYS_utimes)
#endif
#ifdef SYS_mbind
    ASM_DOT_MBT_SYSCALL_MATCH("mbind", SYS_mbind)
#endif
#ifdef SYS_set_mempolicy
    ASM_DOT_MBT_SYSCALL_MATCH("set_mempolicy", SYS_set_mempolicy)
#endif
#ifdef SYS_get_mempolicy
    ASM_DOT_MBT_SYSCALL_MATCH("get_mempolicy", SYS_get_mempolicy)
#endif
#ifdef SYS_mq_open
    ASM_DOT_MBT_SYSCALL_MATCH("mq_open", SYS_mq_open)
#endif
#ifdef SYS_mq_unlink
    ASM_DOT_MBT_SYSCALL_MATCH("mq_unlink", SYS_mq_unlink)
#endif
#ifdef SYS_mq_timedsend
    ASM_DOT_MBT_SYSCALL_MATCH("mq_timedsend", SYS_mq_timedsend)
#endif
#ifdef SYS_mq_timedreceive
    ASM_DOT_MBT_SYSCALL_MATCH("mq_timedreceive", SYS_mq_timedreceive)
#endif
#ifdef SYS_mq_notify
    ASM_DOT_MBT_SYSCALL_MATCH("mq_notify", SYS_mq_notify)
#endif
#ifdef SYS_mq_getsetattr
    ASM_DOT_MBT_SYSCALL_MATCH("mq_getsetattr", SYS_mq_getsetattr)
#endif
#ifdef SYS_kexec_load
    ASM_DOT_MBT_SYSCALL_MATCH("kexec_load", SYS_kexec_load)
#endif
#ifdef SYS_waitid
    ASM_DOT_MBT_SYSCALL_MATCH("waitid", SYS_waitid)
#endif
#ifdef SYS_add_key
    ASM_DOT_MBT_SYSCALL_MATCH("add_key", SYS_add_key)
#endif
#ifdef SYS_request_key
    ASM_DOT_MBT_SYSCALL_MATCH("request_key", SYS_request_key)
#endif
#ifdef SYS_keyctl
    ASM_DOT_MBT_SYSCALL_MATCH("keyctl", SYS_keyctl)
#endif
#ifdef SYS_ioprio_set
    ASM_DOT_MBT_SYSCALL_MATCH("ioprio_set", SYS_ioprio_set)
#endif
#ifdef SYS_ioprio_get
    ASM_DOT_MBT_SYSCALL_MATCH("ioprio_get", SYS_ioprio_get)
#endif
#ifdef SYS_inotify_init
    ASM_DOT_MBT_SYSCALL_MATCH("inotify_init", SYS_inotify_init)
#endif
#ifdef SYS_inotify_add_watch
    ASM_DOT_MBT_SYSCALL_MATCH("inotify_add_watch", SYS_inotify_add_watch)
#endif
#ifdef SYS_inotify_rm_watch
    ASM_DOT_MBT_SYSCALL_MATCH("inotify_rm_watch", SYS_inotify_rm_watch)
#endif
#ifdef SYS_openat
    ASM_DOT_MBT_SYSCALL_MATCH("openat", SYS_openat)
#endif
#ifdef SYS_mkdirat
    ASM_DOT_MBT_SYSCALL_MATCH("mkdirat", SYS_mkdirat)
#endif
#ifdef SYS_mknodat
    ASM_DOT_MBT_SYSCALL_MATCH("mknodat", SYS_mknodat)
#endif
#ifdef SYS_fchownat
    ASM_DOT_MBT_SYSCALL_MATCH("fchownat", SYS_fchownat)
#endif
#ifdef SYS_futimesat
    ASM_DOT_MBT_SYSCALL_MATCH("futimesat", SYS_futimesat)
#endif
#ifdef SYS_newfstatat
    ASM_DOT_MBT_SYSCALL_MATCH("newfstatat", SYS_newfstatat)
#endif
#ifdef SYS_unlinkat
    ASM_DOT_MBT_SYSCALL_MATCH("unlinkat", SYS_unlinkat)
#endif
#ifdef SYS_renameat
    ASM_DOT_MBT_SYSCALL_MATCH("renameat", SYS_renameat)
#endif
#ifdef SYS_linkat
    ASM_DOT_MBT_SYSCALL_MATCH("linkat", SYS_linkat)
#endif
#ifdef SYS_symlinkat
    ASM_DOT_MBT_SYSCALL_MATCH("symlinkat", SYS_symlinkat)
#endif
#ifdef SYS_readlinkat
    ASM_DOT_MBT_SYSCALL_MATCH("readlinkat", SYS_readlinkat)
#endif
#ifdef SYS_fchmodat
    ASM_DOT_MBT_SYSCALL_MATCH("fchmodat", SYS_fchmodat)
#endif
#ifdef SYS_faccessat
    ASM_DOT_MBT_SYSCALL_MATCH("faccessat", SYS_faccessat)
#endif
#ifdef SYS_pselect6
    ASM_DOT_MBT_SYSCALL_MATCH("pselect6", SYS_pselect6)
#endif
#ifdef SYS_ppoll
    ASM_DOT_MBT_SYSCALL_MATCH("ppoll", SYS_ppoll)
#endif
#ifdef SYS_unshare
    ASM_DOT_MBT_SYSCALL_MATCH("unshare", SYS_unshare)
#endif
#ifdef SYS_set_robust_list
    ASM_DOT_MBT_SYSCALL_MATCH("set_robust_list", SYS_set_robust_list)
#endif
#ifdef SYS_get_robust_list
    ASM_DOT_MBT_SYSCALL_MATCH("get_robust_list", SYS_get_robust_list)
#endif
#ifdef SYS_splice
    ASM_DOT_MBT_SYSCALL_MATCH("splice", SYS_splice)
#endif
#ifdef SYS_tee
    ASM_DOT_MBT_SYSCALL_MATCH("tee", SYS_tee)
#endif
#ifdef SYS_sync_file_range
    ASM_DOT_MBT_SYSCALL_MATCH("sync_file_range", SYS_sync_file_range)
#endif
#ifdef SYS_vmsplice
    ASM_DOT_MBT_SYSCALL_MATCH("vmsplice", SYS_vmsplice)
#endif
#ifdef SYS_move_pages
    ASM_DOT_MBT_SYSCALL_MATCH("move_pages", SYS_move_pages)
#endif
#ifdef SYS_utimensat
    ASM_DOT_MBT_SYSCALL_MATCH("utimensat", SYS_utimensat)
#endif
#ifdef SYS_epoll_pwait
    ASM_DOT_MBT_SYSCALL_MATCH("epoll_pwait", SYS_epoll_pwait)
#endif
#ifdef SYS_signalfd
    ASM_DOT_MBT_SYSCALL_MATCH("signalfd", SYS_signalfd)
#endif
#ifdef SYS_timerfd_create
    ASM_DOT_MBT_SYSCALL_MATCH("timerfd_create", SYS_timerfd_create)
#endif
#ifdef SYS_eventfd
    ASM_DOT_MBT_SYSCALL_MATCH("eventfd", SYS_eventfd)
#endif
#ifdef SYS_fallocate
    ASM_DOT_MBT_SYSCALL_MATCH("fallocate", SYS_fallocate)
#endif
#ifdef SYS_timerfd_settime
    ASM_DOT_MBT_SYSCALL_MATCH("timerfd_settime", SYS_timerfd_settime)
#endif
#ifdef SYS_timerfd_gettime
    ASM_DOT_MBT_SYSCALL_MATCH("timerfd_gettime", SYS_timerfd_gettime)
#endif
#ifdef SYS_accept4
    ASM_DOT_MBT_SYSCALL_MATCH("accept4", SYS_accept4)
#endif
#ifdef SYS_signalfd4
    ASM_DOT_MBT_SYSCALL_MATCH("signalfd4", SYS_signalfd4)
#endif
#ifdef SYS_eventfd2
    ASM_DOT_MBT_SYSCALL_MATCH("eventfd2", SYS_eventfd2)
#endif
#ifdef SYS_epoll_create1
    ASM_DOT_MBT_SYSCALL_MATCH("epoll_create1", SYS_epoll_create1)
#endif
#ifdef SYS_dup3
    ASM_DOT_MBT_SYSCALL_MATCH("dup3", SYS_dup3)
#endif
#ifdef SYS_pipe2
    ASM_DOT_MBT_SYSCALL_MATCH("pipe2", SYS_pipe2)
#endif
#ifdef SYS_inotify_init1
    ASM_DOT_MBT_SYSCALL_MATCH("inotify_init1", SYS_inotify_init1)
#endif
#ifdef SYS_preadv
    ASM_DOT_MBT_SYSCALL_MATCH("preadv", SYS_preadv)
#endif
#ifdef SYS_pwritev
    ASM_DOT_MBT_SYSCALL_MATCH("pwritev", SYS_pwritev)
#endif
#ifdef SYS_rt_tgsigqueueinfo
    ASM_DOT_MBT_SYSCALL_MATCH("rt_tgsigqueueinfo", SYS_rt_tgsigqueueinfo)
#endif
#ifdef SYS_perf_event_open
    ASM_DOT_MBT_SYSCALL_MATCH("perf_event_open", SYS_perf_event_open)
#endif
#ifdef SYS_recvmmsg
    ASM_DOT_MBT_SYSCALL_MATCH("recvmmsg", SYS_recvmmsg)
#endif
#ifdef SYS_fanotify_init
    ASM_DOT_MBT_SYSCALL_MATCH("fanotify_init", SYS_fanotify_init)
#endif
#ifdef SYS_fanotify_mark
    ASM_DOT_MBT_SYSCALL_MATCH("fanotify_mark", SYS_fanotify_mark)
#endif
#ifdef SYS_prlimit64
    ASM_DOT_MBT_SYSCALL_MATCH("prlimit64", SYS_prlimit64)
#endif
#ifdef SYS_name_to_handle_at
    ASM_DOT_MBT_SYSCALL_MATCH("name_to_handle_at", SYS_name_to_handle_at)
#endif
#ifdef SYS_open_by_handle_at
    ASM_DOT_MBT_SYSCALL_MATCH("open_by_handle_at", SYS_open_by_handle_at)
#endif
#ifdef SYS_clock_adjtime
    ASM_DOT_MBT_SYSCALL_MATCH("clock_adjtime", SYS_clock_adjtime)
#endif
#ifdef SYS_syncfs
    ASM_DOT_MBT_SYSCALL_MATCH("syncfs", SYS_syncfs)
#endif
#ifdef SYS_sendmmsg
    ASM_DOT_MBT_SYSCALL_MATCH("sendmmsg", SYS_sendmmsg)
#endif
#ifdef SYS_setns
    ASM_DOT_MBT_SYSCALL_MATCH("setns", SYS_setns)
#endif
#ifdef SYS_getcpu
    ASM_DOT_MBT_SYSCALL_MATCH("getcpu", SYS_getcpu)
#endif
#ifdef SYS_process_vm_readv
    ASM_DOT_MBT_SYSCALL_MATCH("process_vm_readv", SYS_process_vm_readv)
#endif
#ifdef SYS_process_vm_writev
    ASM_DOT_MBT_SYSCALL_MATCH("process_vm_writev", SYS_process_vm_writev)
#endif
#ifdef SYS_kcmp
    ASM_DOT_MBT_SYSCALL_MATCH("kcmp", SYS_kcmp)
#endif
#ifdef SYS_finit_module
    ASM_DOT_MBT_SYSCALL_MATCH("finit_module", SYS_finit_module)
#endif
#ifdef SYS_sched_setattr
    ASM_DOT_MBT_SYSCALL_MATCH("sched_setattr", SYS_sched_setattr)
#endif
#ifdef SYS_sched_getattr
    ASM_DOT_MBT_SYSCALL_MATCH("sched_getattr", SYS_sched_getattr)
#endif
#ifdef SYS_renameat2
    ASM_DOT_MBT_SYSCALL_MATCH("renameat2", SYS_renameat2)
#endif
#ifdef SYS_seccomp
    ASM_DOT_MBT_SYSCALL_MATCH("seccomp", SYS_seccomp)
#endif
#ifdef SYS_getrandom
    ASM_DOT_MBT_SYSCALL_MATCH("getrandom", SYS_getrandom)
#endif
#ifdef SYS_memfd_create
    ASM_DOT_MBT_SYSCALL_MATCH("memfd_create", SYS_memfd_create)
#endif
#ifdef SYS_kexec_file_load
    ASM_DOT_MBT_SYSCALL_MATCH("kexec_file_load", SYS_kexec_file_load)
#endif
#ifdef SYS_bpf
    ASM_DOT_MBT_SYSCALL_MATCH("bpf", SYS_bpf)
#endif
#ifdef SYS_execveat
    ASM_DOT_MBT_SYSCALL_MATCH("execveat", SYS_execveat)
#endif
#ifdef SYS_userfaultfd
    ASM_DOT_MBT_SYSCALL_MATCH("userfaultfd", SYS_userfaultfd)
#endif
#ifdef SYS_membarrier
    ASM_DOT_MBT_SYSCALL_MATCH("membarrier", SYS_membarrier)
#endif
#ifdef SYS_mlock2
    ASM_DOT_MBT_SYSCALL_MATCH("mlock2", SYS_mlock2)
#endif
#ifdef SYS_copy_file_range
    ASM_DOT_MBT_SYSCALL_MATCH("copy_file_range", SYS_copy_file_range)
#endif
#ifdef SYS_preadv2
    ASM_DOT_MBT_SYSCALL_MATCH("preadv2", SYS_preadv2)
#endif
#ifdef SYS_pwritev2
    ASM_DOT_MBT_SYSCALL_MATCH("pwritev2", SYS_pwritev2)
#endif
#ifdef SYS_pkey_mprotect
    ASM_DOT_MBT_SYSCALL_MATCH("pkey_mprotect", SYS_pkey_mprotect)
#endif
#ifdef SYS_pkey_alloc
    ASM_DOT_MBT_SYSCALL_MATCH("pkey_alloc", SYS_pkey_alloc)
#endif
#ifdef SYS_pkey_free
    ASM_DOT_MBT_SYSCALL_MATCH("pkey_free", SYS_pkey_free)
#endif
#ifdef SYS_statx
    ASM_DOT_MBT_SYSCALL_MATCH("statx", SYS_statx)
#endif
#ifdef SYS_io_pgetevents
    ASM_DOT_MBT_SYSCALL_MATCH("io_pgetevents", SYS_io_pgetevents)
#endif
#ifdef SYS_rseq
    ASM_DOT_MBT_SYSCALL_MATCH("rseq", SYS_rseq)
#endif
#ifdef SYS_pidfd_send_signal
    ASM_DOT_MBT_SYSCALL_MATCH("pidfd_send_signal", SYS_pidfd_send_signal)
#endif
#ifdef SYS_io_uring_setup
    ASM_DOT_MBT_SYSCALL_MATCH("io_uring_setup", SYS_io_uring_setup)
#endif
#ifdef SYS_io_uring_enter
    ASM_DOT_MBT_SYSCALL_MATCH("io_uring_enter", SYS_io_uring_enter)
#endif
#ifdef SYS_io_uring_register
    ASM_DOT_MBT_SYSCALL_MATCH("io_uring_register", SYS_io_uring_register)
#endif
#ifdef SYS_open_tree
    ASM_DOT_MBT_SYSCALL_MATCH("open_tree", SYS_open_tree)
#endif
#ifdef SYS_move_mount
    ASM_DOT_MBT_SYSCALL_MATCH("move_mount", SYS_move_mount)
#endif
#ifdef SYS_fsopen
    ASM_DOT_MBT_SYSCALL_MATCH("fsopen", SYS_fsopen)
#endif
#ifdef SYS_fsconfig
    ASM_DOT_MBT_SYSCALL_MATCH("fsconfig", SYS_fsconfig)
#endif
#ifdef SYS_fsmount
    ASM_DOT_MBT_SYSCALL_MATCH("fsmount", SYS_fsmount)
#endif
#ifdef SYS_fspick
    ASM_DOT_MBT_SYSCALL_MATCH("fspick", SYS_fspick)
#endif
#ifdef SYS_pidfd_open
    ASM_DOT_MBT_SYSCALL_MATCH("pidfd_open", SYS_pidfd_open)
#endif
#ifdef SYS_clone3
    ASM_DOT_MBT_SYSCALL_MATCH("clone3", SYS_clone3)
#endif
#ifdef SYS_close_range
    ASM_DOT_MBT_SYSCALL_MATCH("close_range", SYS_close_range)
#endif
#ifdef SYS_openat2
    ASM_DOT_MBT_SYSCALL_MATCH("openat2", SYS_openat2)
#endif
#endif
    return -1;
}

// Copy generated bytes into the executable page and call them as a nullary
// function returning its result in RAX.
int64_t asm_dot_mbt_exec(u_int64_t start, const void* machcode, size_t length) {
    memcpy((void*)start, machcode, length);
    int64_t (* fn)(void) = (int64_t (*)(void))start;
    return fn();
}
