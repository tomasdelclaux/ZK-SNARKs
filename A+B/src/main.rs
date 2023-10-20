use ark_ff::Field;
use ark_groth16::Groth16;
use ark_r1cs_std::{
    prelude::{Boolean, EqGadget, AllocVar},
    uint8::UInt8
};
use ark_bls12_377::{Bls12_377, Fr};
use ark_relations::lc;
use ark_relations::r1cs::{SynthesisError, ConstraintSystem, ConstraintSynthesizer, ConstraintSystemRef};
use ark_snark::CircuitSpecificSetupSNARK;
use ark_std::rand::{Rng, RngCore, SeedableRng};
use ark_std::test_rng;


use cmp::CmpGadget;
mod cmp;


struct Puzzle {
    A: Option<usize>,
    B: Option<usize>,
    C:  Option<usize>
}

impl<'a, F: Field> ConstraintSynthesizer<F> for Puzzle {
    fn generate_constraints(self, cs: ConstraintSystemRef<F>) -> Result<(), SynthesisError> {
        let cs = ConstraintSystem::<F>::new_ref();

        let mut a = self.A;
        let mut b = self.B;

        let mut a_value = cs.new_witness_variable(|| a.ok_or(SynthesisError::AssignmentMissing))?;
        let mut b_value = cs.new_witness_variable(|| b.ok_or(SynthesisError::AssignmentMissing))?;

        let c_value = a_value.map(|mut e| {
            e.add_assign(b_value);
            e
        });

        cs.enforce_constraint(
            lc!() + a_value,
            lc!() + b_value,
            lc!() + c_value,
        )?;

        Ok(())
    }
}


fn main() {
    println!("ZERO KNOWLEDGE SUDOKU R1CS");
    use ark_bls12_381::Fq as F;

    let mut rng = ark_std::rand::rngs::StdRng::seed_from_u64(test_rng().next_u64());

    let (pk, vk) = {
        let c = Puzzle<Fr> {
            A:None,
            B:None,
            C:None
        };
        Groth16::<Bls12_377>::setup(c, &mut rng).unwrap()
    };

}