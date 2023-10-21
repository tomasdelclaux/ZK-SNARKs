use ark_ff::Field;
use ark_groth16::Groth16;
use ark_r1cs_std::{
    prelude::{Boolean, EqGadget, AllocVar},
    uint8::UInt8
};
use ark_bls12_381::{Bls12_381, Fr as BlsFr};
use ark_relations::{
    lc, ns,
    r1cs::{ConstraintSynthesizer, ConstraintSystemRef, SynthesisError, Variable},
};
use ark_relations::r1cs::ConstraintSystem;
use ark_snark::{CircuitSpecificSetupSNARK, SNARK};
use ark_std::rand::{Rng, RngCore, SeedableRng};
use ark_std::test_rng;


use cmp::CmpGadget;
mod cmp;

mod alloc;

pub struct Sudoku<const N: usize, ConstraintF: Field>([[UInt8<ConstraintF>; N]; N]);

pub struct Solution<const N: usize, ConstraintF: Field>([[UInt8<ConstraintF>; N]; N]);

struct Puzzle<const N:usize> {
    sudoku: Option<[[u8; N]; N]>,
    solution: Option<[[u8; N]; N]>
}


fn check_rows<const N: usize, ConstraintF: Field>(
    solution: &Solution<N, ConstraintF>,
) -> Result<(), SynthesisError> {
    for row in &solution.0 {
        for (j, cell) in row.iter().enumerate() {
            for prev in &row[0..j] {
                cell.is_neq(&prev)?
                    .enforce_equal(&Boolean::TRUE)?;
            }
        }
    }
    Ok(())
}

fn check_cols<const N: usize, ConstraintF: Field>(
    solution: &Solution<N, ConstraintF>,
)-> Result<(), SynthesisError>{
    let mut transpose:Vec<Vec<UInt8<ConstraintF>>> = Vec::with_capacity(N*N);
    for i in 0..9{
        let col = &solution.0.clone()
            .into_iter()
            .map(|s| s.into_iter().nth(i).unwrap())
            .collect::<Vec<UInt8<ConstraintF>>>();
        transpose.push(col.to_vec());
    }
    for row in transpose {
        for(j, cell) in row.iter().enumerate(){
            for prev in &row[0..j] {
                cell.is_neq(&prev)?.enforce_equal(&Boolean::TRUE)?;
            }
        }
    }
    Ok(())
}

fn check_3By3<const N: usize, ConstraintF: Field>(
    solution: &Solution<N, ConstraintF>
)-> Result<(), SynthesisError>{
    let mut flat:Vec<UInt8<ConstraintF>> = Vec::with_capacity(N*N);
    for i in 0..3{
        for j in 0..3{
            flat.push(solution.0[i][j].clone());
        }
    }
    for (j,cell) in flat.iter().enumerate(){
        for prev in &flat[0..j]{
            cell.is_neq(&prev)?.enforce_equal(&Boolean::TRUE)?;
        }
    }
    Ok(())
}

fn check_sudoku_solution<const N: usize, ConstraintF: Field>(
    sudoku: &Sudoku<N, ConstraintF>,
    solution: &Solution<N, ConstraintF>,
) -> Result<(), SynthesisError> {

    for i in 0..9{
        for j in 0..9{
            let a = &sudoku.0[i][j];
            let b = &solution.0[i][j];
            (a.is_eq(b)?.or(&a.is_eq(&UInt8::constant(0))?)?)
                .enforce_equal(&Boolean::TRUE)?;

            b.is_leq(&UInt8::constant(N as u8))?
                .and(&b.is_geq(&UInt8::constant(1))?)?
                .enforce_equal(&Boolean::TRUE)?;
        }
    }
    Ok(())
}

fn check_helper<const N: usize, ConstraintF: Field>(
    sudoku: &[[u8; N]; N],
    solution: &[[u8; N]; N],
) {
    let cs = ConstraintSystem::<ConstraintF>::new_ref();
    let sudoku_var = Sudoku::new_input(cs.clone(), || Ok(sudoku)).unwrap();
    let solution_var = Solution::new_witness(cs.clone(), || Ok(solution)).unwrap();
    check_sudoku_solution(&sudoku_var, &solution_var).unwrap();
    check_rows(&solution_var).unwrap();
    check_cols(&solution_var).unwrap();
    check_3By3(&solution_var).unwrap();
    assert!(cs.is_satisfied().unwrap());
}

impl<const N:usize, F: Field> ConstraintSynthesizer<F> for Puzzle<N> {
    fn generate_constraints(self, cs: ConstraintSystemRef<F>) -> Result<(), SynthesisError> {
        let mut sudoku = self.sudoku;
        let mut solution = self.solution;

        let mut sudoku_var = Sudoku::new_witness(cs.clone(), || sudoku.ok_or(SynthesisError::AssignmentMissing))?;
        let mut solution_var = Solution::new_witness(cs.clone(), || solution.ok_or(SynthesisError::AssignmentMissing))?;

        check_sudoku_solution(&sudoku_var, &solution_var)?;
        check_rows(&solution_var)?;
        check_cols(&solution_var)?;
        check_3By3(&solution_var)?;
        Ok(())
    }
}


fn main() {

    println!("ZERO KNOWLEDGE SUDOKU R1CS");
    use ark_bls12_381::Fq as F;
    let sudoku = [
        [0,0,0,2,6,0,7,0,1],
        [6,8,0,0,7,0,0,9,0],
        [1,9,0,0,0,4,5,0,0],
        [8,2,0,1,0,0,0,4,0],
        [0,0,4,6,0,2,9,0,0],
        [0,5,0,0,0,3,0,2,8],
        [0,0,9,3,0,0,0,7,4],
        [0,4,0,0,5,0,0,3,6],
        [7,0,3,0,1,8,0,0,0]
    ];
    let solution = [
        [4,3,5,2,6,9,7,8,1],
        [6,8,2,5,7,1,4,9,3],
        [1,9,7,8,3,4,5,6,2],
        [8,2,6,1,9,5,3,4,7],
        [3,7,4,6,8,2,9,1,5],
        [9,5,1,7,4,3,6,2,8],
        [5,1,9,3,2,6,8,7,4],
        [2,4,8,9,5,7,1,3,6],
        [7,6,3,4,1,8,2,5,9]
    ];

    //To check correctness of zero knowledge proof
    // check_helper::<9, F>(&sudoku, &solution);

    // This may not be cryptographically safe, use
    // `OsRng` (for example) in production software.
    let mut rng = ark_std::rand::rngs::StdRng::seed_from_u64(test_rng().next_u64());

    //CIRCUIT SET UP
    println!("SET UP CIRCUIT AND GENERATE PK AND VK");
    let (pk, vk) = {
        let c = Puzzle::<9> {
            sudoku:None,
            solution:None
        };
        Groth16::<Bls12_381>::setup(c, &mut rng).unwrap()
    };

    //GENERATE PROOFS
    println!("GENERATE PROOF");
    let example = Puzzle::<9>{
        sudoku:Some(sudoku),
        solution:Some(solution)
    };

    let proof = Groth16::<Bls12_381>::prove(&pk, example, &mut rng).unwrap();

    //VERIFY PROOF
    println!("VERIFIY PROOF");
    let mut flat:Vec<BlsFr> = Vec::with_capacity(9*9);
    for i in 0..9{
        for j in 0..9{
            flat.push(BlsFr::from(sudoku[i][j]));
        }
    }

    // let xl = rng.gen();
    assert!(
        Groth16::<Bls12_381>::verify(&vk, &[], &proof).unwrap()
    );
}