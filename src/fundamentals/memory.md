# Memory

One of the coolest things about computers is that they are extremely complex machines that can execute a wide variety of tasks. Somehow humanity went from making fire to building machines that harness the physicalproperties of silicon and electrons to do that. Yet, at a higher abstraction level, their building blocks are quite simple and elegant.

A computer program is basically just a bunch of instructions and data. Instructions execute one after another and tell the CPU how to manipulate that data.

One interesting aspect of data is that it doesn't come in a single shape or form. Some data lives through the entirety of the execution of the program. Some data has a very short lifetime. There's even data whose size, or how long it'll live, we don't know while we're writing the program, but we can still use abstractions to handle it while the program is running.

When your computer executes a program, the operating system hands the program an address space -- a private range of addresses. The program is blind to how this range of addresses is actually laid out on the hardware. This is a problem for the OS to solve.

The instructions and data of the program live in the address space and are laid out in a standard shape. It looks like this:

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

On the very "bottom" lives the machine code of the program, the instructions that control its behavior. Next to it, there's a block responsible for storing static data. Finally, we have the stack and the heap, which grow towards each other.

## Static Data

Static data is embedded in the address space of the application, just above the machine code of the program. This region can store anything that lives through the whole execution of the program. Global variables, string literals, (sometimes) constants... From the point of view of the application, these values live forever. That's why they're called _static_.

We can also say that they have a static lifetime:

```rust
static VALUE: &str = "HELLO"; // static that's embedded in the binary

fn main() {
    println!("{VALUE}");
}
```

> By the way, in Rust all static data has a static lifetime, but not all values that have a static lifetime live on the static segment of the address space.

This is the simplest abstraction available for holding values in memory. It's so simple that you can do almost nothing useful with it.

## The Stack

The stack (also known as the _call stack_) is the **region of memory that's used to manage function calls**. Its main goal is to **keep track of where each function call should return** control when it finishes executing. When you call a function, space is set aside in memory for that function to do its work. This space is called the **stack frame**. The frame at the top of the stack is always the function that's currently executing.

> Top and bottom can get confusing here, since the stack grows downwards in memory. The lower the address, the closer to the top of the stack you'll be.

**Calling** a function **pushes** a new frame onto the stack. **Returning** from a function **pops** the frame off the stack.

### What does the stack frame hold?

1. Return address: an address that points to the **machine code** region of the program's memory that tells the program where in the caller to resume when the function finishes.
2. Saved frame pointer: an address that points to the **stack frame** of the caller. It tells the program where the data of the caller function lives.
3. Arguments: the parameters you pass into the function.
4. Local variables: the named slots that will hold the temporary values the function will use.

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

* `main`'s frame reserves room for `a` and `c` the moment it is entered; the `?` means the space exists but nothing has been written to it yet.
* `add`'s frame comes into existence when the call happens and is gone when the function returns. And the two `a`s stay separate: the call **copies** the 24 out of `main`'s frame into `add`'s.
* `return c` also copies 48 out into `main`'s `c`.

### Pop does not delete

When a frame is popped, no data gets deleted. It just sits there until something overwrites it. In a low-level programming language like C, nothing stops you from holding on to a pointer into a frame that has already been popped and reading it anyway. What you get back is **undefined behavior**.

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

`overwrite` was handed the same stack space as `leak`, and `y` was written to the exact address that was used to hold `x`. Since compilers nowadays are smarter, we had to do some tricks to trigger the UB. Check out what the program prints if you comment out the `overwrite` call.

Rust, on the other hand, doesn't even compile if you try to do that:

```rust
fn broken() -> &'static i32 {
    let x = 42;
    &x // error[E0515]: cannot return reference to local variable `x`
}
```

### Other

Other interesting stuff to know about the stack:

* It has a fixed, limited size. Main thread usually gets 8 MiB, blow past it and you get a **stack overflow**.
* The size of every stack frame is computed at compile time. This means that everything that goes into the stack **must have a known size at compile time**.
* There's one per thread.
* You don't need to manage it. The compiler and OS will handle that for you.
* It's very fast when compared to allocating memory on the heap. Allocation is just pointer arithmetic.

## The Heap

The heap is the region of the address space that **stores dynamically allocated data**: data whose size or lifetime we don't know while the program is being compiled.

Where a stack frame's size is baked in at compile time and the frame dies when the function returns, the heap drops both constraints. You ask for space **while the program is running**, and it stays yours until you hand it back.

Asking for space is a function call. The **allocator** keeps track of which parts of the heap are in use, finds a chunk big enough, and gives you back its address. In C that's `malloc` and `free`. In Rust you rarely talk to the allocator yourself. Types like `Box`, `Vec` and `String` do it for you.

### Why the stack isn't enough

1. **The size isn't known at compile time.** A line the user types, a file you read, a list that grows. The stack needs a number at compile time and you don't have one.
2. **The data has to outlive the frame that created it.** A function that builds something and returns it can't leave it in its own frame.
3. **The data is too big.** The main thread usually gets 8 MiB for the whole stack.

A pointer, on the other hand, is small and always the same size. So the usual shape is that **the pointer lives on the stack and the data it points to lives on the heap**:

```text
   stack frame of main               heap
 +----------------------+        +---+---+---+---+---------------+
 | v.ptr  --------------+------> | 1 | 2 | 3 | 4 |    (free)     |
 | v.len: 4             |        +---+---+---+---+---------------+
 | v.cap: 4             |
 +----------------------+
```

### Example

A `Vec` is exactly that: three fields on the stack, the elements on the heap.

```rust
fn main() {
    let mut v: Vec<i64> = Vec::new();

    for i in 0..4 {
        v.push(i);
        println!("len {} cap {} ptr {:p}", v.len(), v.capacity(), v.as_ptr());
    }
}
```

```console
$ ./grow
len 1 cap 4 ptr 0x5f23474dcb50
len 2 cap 4 ptr 0x5f23474dcb50
len 3 cap 4 ptr 0x5f23474dcb50
len 4 cap 4 ptr 0x5f23474dcb50
```

* `Vec::new()` doesn't allocate anything. There are no elements yet, so there's nothing to hold them in.
* The first `push` asks the allocator for room and gets back a chunk with space for 4. Pushes 2, 3 and 4 are just writes into space that already exists.

### Free does not delete

`free` just tells the allocator the chunk is available again. Your pointer still holds the same address. It's now a **dangling pointer**, and reading through it is **undefined behavior**.

```c
#include <stdio.h>
#include <stdlib.h>

int main(void) {
    int *p = malloc(sizeof(int));
    *p = 42;
    printf("p  = %p holds %d\n", (void *)p, *p);

    free(p);                       // chunk goes back to the allocator, bytes stay put

    int *q = malloc(sizeof(int));  // same size, so the same chunk comes back
    *q = 99;
    printf("q  = %p holds %d\n", (void *)q, *q);
    printf("*p = %d\n", *p);       // reads q through a pointer to a freed chunk
}
```

```console
$ gcc -O0 -o uaf uaf.c
$ ./uaf
p  = 0x5e02e1cbd310 holds 42
q  = 0x5e02e1cbd310 holds 99
*p = 99
```

Rust stops this with ownership. `drop` takes the `Box` by value, so the value is moved and the name is dead from that point on:

```rust
fn main() {
    let b = Box::new(42);
    drop(b);
    println!("{b}"); // error[E0382]: borrow of moved value: `b`
}
```

There are two more ways to get the heap wrong, and the stack can't produce either of them:

* **Double free**: freeing the same chunk twice corrupts the allocator's own bookkeeping.
* **Leak**: never freeing. Nothing crashes, the program just keeps growing.

### Other

Other interesting stuff to know about the heap:

* It has no fixed size the way the stack does. When the allocator runs out of room it asks the OS for more, until RAM and swap run out or the OS says no.
* There's one per process, shared by every thread. The allocator has to synchronize access, which is part of why it's slower.
* Allocating is not pointer arithmetic. It's bookkeeping plus a search for a chunk that fits, which makes it orders of magnitude slower than pushing a frame.
* Free chunks get scattered around as the program runs. That's **fragmentation**, and it means a large request can fail even when the total free space would have been enough.
* Reaching heap data costs an extra hop through a pointer, and that data is unlikely to be in cache. Stack data usually already is.
* Somebody has to free it: you by hand in C, the type system in Rust, a garbage collector elsewhere.

## Lifetimes

Everything on this page has really been about one question: **when does the memory holding this value go away?** The answer to that question is the value's **lifetime** -- the span between the moment it comes into existence and the moment its memory is taken back.

Every value in every language has one. What the three regions give you are three different ways of answering it:

| Region | Lifetime starts | Lifetime ends | Who decides |
|---|---|---|---|
| Static data | before `main` runs, it's in the binary | never, the program exits first | the compiler, at compile time |
| Stack | when the frame is pushed | when the frame is popped | the shape of your call graph |
| Heap | when you ask the allocator | when someone frees it | you, at runtime |

```text
time ------------------------------------------------------------------->

 static  |=====================================================| exit
         ^ already there before main

 stack        |==========|          |=====|
              push       pop        push  pop

 heap              |============================|
                   alloc                        free
```

Static and stack lifetimes are **decided at compile time** -- the compiler knows where the binary's data segment ends up and it knows where every `push` and `pop` goes, because they're determined by the code, not by what the code computes. Heap lifetimes are the odd one out: **nothing in the source says when the chunk goes back**. That's a decision made while the program runs.

### It's always the same bug

Both C examples here are the same mistake wearing different clothes. In both cases the value's lifetime ended and the pointer's didn't. The pointer outlived the thing it pointed at, and **nothing about the pointer changed to tell you so**. The only difference is which part of the address space the pointer pointed into.

### Three ways out

1. **Trust the programmer.** You keep the lifetimes in your head and write `free` in the right place. When you're wrong you get undefined behavior. Total control, fast but error-prone.
2. **Decide at runtime.** A garbage collector handles data allocation and deallocation while the program runs. The dangling pointer becomes impossible, but you pay an overhead at runtime, because the collector halts the program to do its work and you don't know exactly when that's going to happen. No control, slow and safe.
3. **Prove it at compile time.** The compiler tracks, for every reference, the region of code where its referent is guaranteed alive, and refuses to compile a program where a reference escapes that region. You pay for it in compile errors instead of crashes, and the checking leaves nothing behind at runtime. No control, fast and safe.

## Summary

* **A program is instructions and data.** The OS hands it a private address space, laid out in a standard shape: machine code, static data, heap and stack.
* **Static data is embedded in the binary.** Globals, string literals, some constants. It's there before `main` starts and it's never freed.
* **The stack manages function calls.** Calling pushes a frame, returning pops it, and the frame holds the return address, the saved frame pointer, the arguments and the locals. Frame sizes are computed at compile time, which is why everything on the stack needs a size known at compile time.
* **The heap holds what the stack can't.** Data whose size or lifetime isn't known until the program runs. You ask the allocator for a chunk and get back a pointer: the pointer lives on the stack, the data lives on the heap.
* **Neither popping nor freeing erases anything.** Both just mark the space reusable. A pointer into space that's been given back is a **dangling pointer**, and reading through it is undefined behavior.
* **The stack is fast and automatic, the heap is flexible and expensive.** Pushing a frame is pointer arithmetic. Allocating is bookkeeping, a search for a chunk that fits, and synchronization with every other thread. Default to the stack, reach for the heap when you have a reason.
* **A lifetime is the span between a value's creation and its memory being taken back.** Static lifetimes run for the whole program, stack lifetimes follow the call graph, heap lifetimes are decided while the program runs.
* **The hard part isn't allocating, it's making sure no reference outlives what it refers to.** Languages answer that by trusting you (C), checking at runtime (garbage collection), or proving it at compile time (Rust).
