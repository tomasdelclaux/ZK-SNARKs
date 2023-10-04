# Zokrates

Zokrates is the easiest to use straight out of the box. Let's try a sudoku problem in zokrates

To install zokrates:

```
curl -LSfs get.zokrat.es | sh
export PATH=$PATH:$HOME/.zokrates/bin
export ZOKRATES_HOME=$HOME/.zokrates/stdlib
```

## SUDOKU

The file sudoku.rok is the R1CS representation of the sudoku problem. It checks that a solution
contains rows with unique elements, columns with unique elements, 3x3 matrices with distinct elements
and that it matches the actual problem.

## COMPILE R1CS

```
zokrates compile -i sudoku.rok
Compiling sudoku.rok

Compiled code written to 'out'
Number of constraints: 121654
```

## GENERATE PROVING KEY AND VERIFICATION KEY

```
zokrates setup
Performing setup...
Verification key written to 'verification.key'
Proving key written to 'proving.key'
Setup completed
```

## COMPUTE A WITNESS

The witness below is the equivalent of the following problem:

```
SUDOKU

0 0 0 2 6 0 7 0 1
6 8 0 0 7 0 0 9 0
1 9 0 0 0 4 5 0 0
8 2 0 1 0 0 0 4 0
0 0 4 6 0 2 9 0 0
0 5 0 0 0 3 0 2 8
0 0 9 3 0 0 0 7 4
0 4 0 0 5 0 0 3 6
7 0 3 0 1 8 0 0 0

0 0 0 2 6 0 7 0 1 6 8 0 0 7 0 0 9 0 1 9 0 0 0 4 5 0 0 8 2 0 1 0 0 0 4 0 0 0 4 6 0 2 9 0 0 0 5 0 0 0 3 0 2 8 0 0 9 3 0 0 0 7 4 0 4 0 0 5 0 0 3 6 7 0 3 0 1 8 0 0 0

SOLUTION

4 3 5 2 6 9 7 8 1
6 8 2 5 7 1 4 9 3
1 9 7 8 3 4 5 6 2
8 2 6 1 9 5 3 4 7
3 7 4 6 8 2 9 1 5
9 5 1 7 4 3 6 2 8
5 1 9 3 2 6 8 7 4
2 4 8 9 5 7 1 3 6
7 6 3 4 1 8 2 5 9


4 3 5 2 6 9 7 8 1 6 8 2 5 7 1 4 9 3 1 9 7 8 3 4 5 6 2 8 2 6 1 9 5 3 4 7 3 7 4 6 8 2 9 1 5 9 5 1 7 4 3 6 2 8 5 1 9 3 2 6 8 7 4 2 4 8 9 5 7 1 3 6 7 6 3 4 1 8 2 5 9
```

```
zokrates compute-witness -a 0 0 0 2 6 0 7 0 1 6 8 0 0 7 0 0 9 0 1 9 0 0 0 4 5 0 0 8 2 0 1 0 0 0 4 0 0 0 4 6 0 2 9 0 0 0 5 0 0 0 3 0 2 8 0 0 9 3 0 0 0 7 4 0 4 0 0 5 0 0 3 6 7 0 3 0 1 8 0 0 0 4 3 5 2 6 9 7 8 1 6 8 2 5 7 1 4 9 3 1 9 7 8 3 4 5 6 2 8 2 6 1 9 5 3 4 7 3 7 4 6 8 2 9 1 5 9 5 1 7 4 3 6 2 8 5 1 9 3 2 6 8 7 4 2 4 8 9 5 7 1 3 6 7 6 3 4 1 8 2 5 9
Computing witness...
Witness file written to 'witness'
```

## GENERATE THE PROOF

```
zokrates generate-proof
Generating proof...
Proof written to 'proof.json'
```

## VERIFY PROOF

```
zokrates verify
Performing verification...
PASSED
```

## GENERATE A VERIFIER SOLIDITY SMART CONTRACT

```
zokrates export-verifier
Exporting verifier...
Verifier exported to 'verifier.sol'
```