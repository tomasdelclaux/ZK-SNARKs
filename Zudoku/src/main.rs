use ark_ff::Field;
use ark_groth16::Groth16;
use ark_r1cs_std::{
    prelude::{Boolean, EqGadget, AllocVar},
    uint8::UInt8
};
use ark_bls12_377::{Bls12_377, Fr};
use ark_relations::r1cs::{SynthesisError, ConstraintSystem};
use ark_snark::CircuitSpecificSetupSNARK;
use ark_std::rand::{Rng, RngCore, SeedableRng};
use ark_std::test_rng;


use cmp::CmpGadget;
mod cmp;

mod alloc;

pub struct Sudoku<const N: usize, ConstraintF: Field>([[UInt8<ConstraintF>; N]; N]);

pub struct Solution<const N: usize, ConstraintF: Field>([[UInt8<ConstraintF>; N]; N]);


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

impl<'a, F: Field> ConstraintSynthesizer<F> for MiMCDemo<'a, F> {
    fn generate_constraints(self, cs: ConstraintSystemRef<F>) -> Result<(), SynthesisError> {
        assert_eq!(self.constants.len(), MIMC_ROUNDS);

        // Allocate the first component of the preimage.
        let mut xl_value = self.xl;
        let mut xl =
            cs.new_witness_variable(|| xl_value.ok_or(SynthesisError::AssignmentMissing))?;

        // Allocate the second component of the preimage.
        let mut xr_value = self.xr;
        let mut xr =
            cs.new_witness_variable(|| xr_value.ok_or(SynthesisError::AssignmentMissing))?;

        for i in 0..MIMC_ROUNDS {
            // xL, xR := xR + (xL + Ci)^3, xL
            let ns = ns!(cs, "round");
            let cs = ns.cs();

            // tmp = (xL + Ci)^2
            let tmp_value = xl_value.map(|mut e| {
                e.add_assign(&self.constants[i]);
                e.square_in_place();
                e
            });
            let tmp =
                cs.new_witness_variable(|| tmp_value.ok_or(SynthesisError::AssignmentMissing))?;

            cs.enforce_constraint(
                lc!() + xl + (self.constants[i], Variable::One),
                lc!() + xl + (self.constants[i], Variable::One),
                lc!() + tmp,
            )?;

            // new_xL = xR + (xL + Ci)^3
            // new_xL = xR + tmp * (xL + Ci)
            // new_xL - xR = tmp * (xL + Ci)
            let new_xl_value = xl_value.map(|mut e| {
                e.add_assign(&self.constants[i]);
                e.mul_assign(&tmp_value.unwrap());
                e.add_assign(&xr_value.unwrap());
                e
            });

            let new_xl = if i == (MIMC_ROUNDS - 1) {
                // This is the last round, xL is our image and so
                // we allocate a public input.
                cs.new_input_variable(|| new_xl_value.ok_or(SynthesisError::AssignmentMissing))?
            } else {
                cs.new_witness_variable(|| new_xl_value.ok_or(SynthesisError::AssignmentMissing))?
            };

            cs.enforce_constraint(
                lc!() + tmp,
                lc!() + xl + (self.constants[i], Variable::One),
                lc!() + new_xl - xr,
            )?;

            // xR = xL
            xr = xl;
            xr_value = xl_value;

            // xL = new_xL
            xl = new_xl;
            xl_value = new_xl_value;
        }

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
    check_helper::<9, F>(&sudoku, &solution);

    // This may not be cryptographically safe, use
    // `OsRng` (for example) in production software.
    let mut rng = ark_std::rand::rngs::StdRng::seed_from_u64(test_rng().next_u64());

    let (pk, vk) = {
        let cs = ConstraintSystem::<Fr>::new_ref();
        let sudoku_var = Sudoku::new_input(cs.clone(), || Ok(sudoku)).unwrap();
        let solution_var = Solution::new_witness(cs.clone(), || Ok(solution)).unwrap();
        Groth16::<Bls12_377>::setup(cs, &mut rng).unwrap()
    };
}