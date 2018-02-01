Change `Number_Of_Workers` in `Orka.Jobs.Boss` (line 47) to > 1 (for
example 2) to see that the `Future` slot will no longer be always released.

You should see that sometimes there are too many references (output
"references C" should be 1) and sometimes too few, so the `Future` gets
released to early.

Modify the 2nd and 3rd parameter of `Orka.Jobs.Parallelize` in
`examples/orka_test-test_9_jobs.adb` on line 32 to control how many parallel
jobs will be created. The more there are, the easier it is to reproduce the
problem.

Compile with `make`, clean with `make clean`.

Tested with GNAT FSF 7.2 on Ubuntu 17.10
