# Memory

I think that one of the coolest things about computers is that they are extremely complex machines and yet the fundamentals of how they work are simple in comparison.

A computer program is basically just a bunch of instructions and data. Instructions execute one after another, and tell the CPU how to manipulate that data. That data has to live somewhere, and memory is the abstraction that was built to handle it.

When you ask your computer to execute a program, the operating system takes a piece of memory and gives it to the program to run in. This piece of memory holds:

1. Machine code (aka the instructions of the program)
2. Static data (constants and static variables the program declares)
3. Stack
4. Heap

Laid out from the highest address down to the lowest, it looks like this:

```text
     high addresses
    +-----------------+
    |      Stack      |
    |        |        |
    |        v        |
    |                 |
    |   (free space)  |
    |                 |
    |        ^        |
    |        |        |
    |      Heap       |
    +-----------------+
    |   Static data   |
    +-----------------+
    |   Machine code  |
    +-----------------+
     low addresses
```

## Static Data

Static data is embedded in the memory of the application, just above the machine code (instructions) of the program. Global variables, string literals, constants, they all live here. From the point of view of the application, these values live forever. The program is born with them and dies with them, and that's why they're called _static_.

```rust
static VALUE: &str = "HELLO"; // static that's embedded on the memory

fn main() {
    println!("{VALUE}");
}
```

This is the simplest abstraction for holding values in memory available. It's in fact so simple that you can do almost nothing useful with it.

## The Stack

The stack, (also known as _call stack_) is the **region of memory that's used to manage function calls**. Its main goal is to **keep track of where each function call should return** control when it finishes executing. When you call a function, the OS sets aside space in memory for that function to do its necessary work. This space is called the **stack frame**. The frame at the top of the stack is always the function that's currently executing.

> Top and bottom can get confusing here, since the stack grows downwards in memory. The lower the address, the closer to the top of the stack you'll be.

**Calling** a function, **pushes** a new frame on the stack. **Returning** from a function **pops** the frame off the stack.

### What does the stack frame holds?

1. Return address: an address that points to the **machine code** region of the program's memory that tells the program where in the caller to resume when the function finishes.
2. Saved frame pointer: an address that point to the **stack frame** of the caller. It tells the program where the data of the caller function lives.
3. Arguments: the parameters you pass into the function.
4. Local variables: the name slots that will hold the temporary values the function will use.

```text
  higher addresses
 +----------------------+
 | arg 7, arg 8, ...    |
 +----------------------+
 | return address       |
 +----------------------+
 | saved frame pointer  |
 +----------------------+
 | local variables      |
 +----------------------+
  lower addresses (top of stack)
```

### Example

```rust
fn add(a: i64) -> i64 {
    let b = 24;
    let c = a + b;

    return c;
}

fn main() {
    let a = 24;
    let c = add(a);

    println!("{c}");
}
```

Reading left to right as the program runs, the stack looks like this. Each column is one step in time, and the frames grow downwards, the same direction as the diagram further up the page.

```text
time --------------------------------------------------------------------------------->

         fn main()    let a=24     add(a)       let b=24     let c=a+b    return c     println!
         entered                   called                                 pops

        +------------+------------+------------+------------+------------+------------+------------+
  main  | ret: libc  | ret: libc  | ret: libc  | ret: libc  | ret: libc  | ret: libc  | ret: libc  |
        | sfp: libc  | sfp: libc  | sfp: libc  | sfp: libc  | sfp: libc  | sfp: libc  | sfp: libc  |
        | a: ?       | a: 24      | a: 24      | a: 24      | a: 24      | a: 24      | a: 24      |
        | c: ?       | c: ?       | c: ?       | c: ?       | c: ?       | c: 48      | c: 48      |
        +------------+------------+------------+------------+------------+------------+------------+
                                  +------------+------------+------------+
  add                             | ret: main  | ret: main  | ret: main  |
                                  | sfp: main  | sfp: main  | sfp: main  |
                                  | a: 24      | a: 24      | a: 24      |
                                  | b: ?       | b: 24      | b: 24      |
                                  | c: ?       | c: ?       | c: 48      |
                                  +------------+------------+------------+
```

`ret` and `sfp` are the return address and the saved frame pointer.

* `main`'s frame reserves room for `a` and `c` the moment it is entered, the `?` means the space exists but nothing has been written to it yet.
* `add`'s frame comes into existence when the call happens and is gone when function returns. And the two `a`s stay separate: the call **copies** the 24 out of `main`'s frame into `add`'s.
* `return c` also copies 48 out into `main`'s `c`.

### Pop does not delete

When a frame is popped, no data get's deleted. It just sits there until something overwrites it. In a low level programming language like C, nothing stops you from holding on to a pointer into a frame that has already been popped and reading it anyway. What you get back is **undefined behavior**.

```c
#include <stdio.h>

int *hide(int *p) { return p; }

int *leak(void) {
    int x = 42;
    return hide(&x);     // hand back a pointer into a frame about to be popped
}

void overwrite(void) {
    volatile int y = 99; // lands on the bytes leak() just gave up
}

int main(void) {
    int *p = leak();     // p points into a dead frame
    overwrite();         // that frame gets reused
    printf("%d\n", *p);  // reads y through a pointer to x
}
```

```console
$ gcc -O0 -fno-stack-protector -o ub ub.c
$ ./ub
99
```

`overwrite` was handed the same stack space than `leak`, and `y` was written to the exact address that was used to hold `x`. Since compilers nowadays are smarter, we had to do some tricks to trigger the UB. Checkout what the program prints if you comment out the `overwrite` call.

Rust, in the other hand, doesn't even compile if you try to do that:

```rust
fn broken() -> &'static i32 {
    let x = 42;
    &x // error[E0515]: cannot return reference to local variable `x`
}
```

### Other

Other intersting stuff to know about the stack:

* It has a fixed, limited size. Main thread usually gets 8 MiB, blow past it and you get a **stack overflow**.
* The size of every stack frame is computed at compile time. This means that everything that goes into the stack **must have a known size at compile time**.
* There's one per thread.
* You don't need to manage it. The compiler and OS will handle that for you.
* It's very fast when compared to allocating memory on the heap. Allocation is just pointer arithmetic.

## The Heap

TBD

## Lifetimes

How does all of this ties to the program your writting?

TBD
