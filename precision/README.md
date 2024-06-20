## Precision in SAS numbers and IEEE floating point math

This sample program and output are companions [to this blog post that describes
how floating point numbers](https://blogs.sas.com/content/sasdummy/precision-in-sas-numbers/) are represented in SAS (and in many other programming languages). Percieved precision errors are often just a byproduct of how modern computers represent decimal numbers.

* [precision_example.sas](./precision_example.sas)
* [Precision example output](./precision-output.html)

### Summary

* SAS fully exploits the hardware on which it runs to calculate correct and complete results using numbers of high precision and large magnitude.

* By rounding to 15 significant digits, the _w.d_ format maps a range of base-2 values to each base-10 value. This is usually what you want, but not when you're digging into very small differences.

* Numeric operations in the DATA step use all of the range and precision supported by the hardware. This can be more than you had in mind, and includes more precision than the _w.d_ format displays.

* SAS has a rich set of tools that the savvy SAS consultant can employ to diagnose unexpected behavior with floating-point numbers.