// This file is MIT Licensed.
//
// Copyright 2017 Christian Reitwiessner
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
pragma solidity ^0.8.0;
library Pairing {
    struct G1Point {
        uint X;
        uint Y;
    }
    // Encoding of field elements is: X[0] * z + X[1]
    struct G2Point {
        uint[2] X;
        uint[2] Y;
    }
    /// @return the generator of G1
    function P1() pure internal returns (G1Point memory) {
        return G1Point(1, 2);
    }
    /// @return the generator of G2
    function P2() pure internal returns (G2Point memory) {
        return G2Point(
            [10857046999023057135944570762232829481370756359578518086990519993285655852781,
             11559732032986387107991004021392285783925812861821192530917403151452391805634],
            [8495653923123431417604973247489272438418190587263600148770280649306958101930,
             4082367875863433681332203403145435568316851327593401208105741076214120093531]
        );
    }
    /// @return the negation of p, i.e. p.addition(p.negate()) should be zero.
    function negate(G1Point memory p) pure internal returns (G1Point memory) {
        // The prime q in the base field F_q for G1
        uint q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
        if (p.X == 0 && p.Y == 0)
            return G1Point(0, 0);
        return G1Point(p.X, q - (p.Y % q));
    }
    /// @return r the sum of two points of G1
    function addition(G1Point memory p1, G1Point memory p2) internal view returns (G1Point memory r) {
        uint[4] memory input;
        input[0] = p1.X;
        input[1] = p1.Y;
        input[2] = p2.X;
        input[3] = p2.Y;
        bool success;
        assembly {
            success := staticcall(sub(gas(), 2000), 6, input, 0xc0, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success);
    }


    /// @return r the product of a point on G1 and a scalar, i.e.
    /// p == p.scalar_mul(1) and p.addition(p) == p.scalar_mul(2) for all points p.
    function scalar_mul(G1Point memory p, uint s) internal view returns (G1Point memory r) {
        uint[3] memory input;
        input[0] = p.X;
        input[1] = p.Y;
        input[2] = s;
        bool success;
        assembly {
            success := staticcall(sub(gas(), 2000), 7, input, 0x80, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require (success);
    }
    /// @return the result of computing the pairing check
    /// e(p1[0], p2[0]) *  .... * e(p1[n], p2[n]) == 1
    /// For example pairing([P1(), P1().negate()], [P2(), P2()]) should
    /// return true.
    function pairing(G1Point[] memory p1, G2Point[] memory p2) internal view returns (bool) {
        require(p1.length == p2.length);
        uint elements = p1.length;
        uint inputSize = elements * 6;
        uint[] memory input = new uint[](inputSize);
        for (uint i = 0; i < elements; i++)
        {
            input[i * 6 + 0] = p1[i].X;
            input[i * 6 + 1] = p1[i].Y;
            input[i * 6 + 2] = p2[i].X[1];
            input[i * 6 + 3] = p2[i].X[0];
            input[i * 6 + 4] = p2[i].Y[1];
            input[i * 6 + 5] = p2[i].Y[0];
        }
        uint[1] memory out;
        bool success;
        assembly {
            success := staticcall(sub(gas(), 2000), 8, add(input, 0x20), mul(inputSize, 0x20), out, 0x20)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success);
        return out[0] != 0;
    }
    /// Convenience method for a pairing check for two pairs.
    function pairingProd2(G1Point memory a1, G2Point memory a2, G1Point memory b1, G2Point memory b2) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](2);
        G2Point[] memory p2 = new G2Point[](2);
        p1[0] = a1;
        p1[1] = b1;
        p2[0] = a2;
        p2[1] = b2;
        return pairing(p1, p2);
    }
    /// Convenience method for a pairing check for three pairs.
    function pairingProd3(
            G1Point memory a1, G2Point memory a2,
            G1Point memory b1, G2Point memory b2,
            G1Point memory c1, G2Point memory c2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](3);
        G2Point[] memory p2 = new G2Point[](3);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        return pairing(p1, p2);
    }
    /// Convenience method for a pairing check for four pairs.
    function pairingProd4(
            G1Point memory a1, G2Point memory a2,
            G1Point memory b1, G2Point memory b2,
            G1Point memory c1, G2Point memory c2,
            G1Point memory d1, G2Point memory d2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](4);
        G2Point[] memory p2 = new G2Point[](4);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p1[3] = d1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        p2[3] = d2;
        return pairing(p1, p2);
    }
}

contract Verifier {
    using Pairing for *;
    struct VerifyingKey {
        Pairing.G1Point alpha;
        Pairing.G2Point beta;
        Pairing.G2Point gamma;
        Pairing.G2Point delta;
        Pairing.G1Point[] gamma_abc;
    }
    struct Proof {
        Pairing.G1Point a;
        Pairing.G2Point b;
        Pairing.G1Point c;
    }
    function verifyingKey() pure internal returns (VerifyingKey memory vk) {
        vk.alpha = Pairing.G1Point(uint256(0x291589b21260b5ce6460777f1b20d066a00cc54192e4398d6e34a50a70330d26), uint256(0x08077f94dc35a6226c89521f7fbb5311398552b72a435fe4487e714a8d34aa9a));
        vk.beta = Pairing.G2Point([uint256(0x0e4d93ea07b4ed77e2a7ef3d289ec3a529f8f871ecc40a79874d2195d77d916d), uint256(0x235b0c51fb898063a11b5591c73eb95db5ee35a3c5af0453c3b737f53f44a336)], [uint256(0x252709473ea4ccf429f7d9bcb85a1257890e30504b7636ee2a30fcaff3edd571), uint256(0x14d0febc5838cdc60732efcbaa43ad28be892bea81b9769c3bd111c215d980df)]);
        vk.gamma = Pairing.G2Point([uint256(0x0f7cc67d21078bd23b62b3109e9278574436d87edd5eba3eea9f54315352c874), uint256(0x23e4627c5f2de26953a03cb8190ad0a58152df0fb2c1e535454a759be5fdd71f)], [uint256(0x304a96e9abe24d8d1b78679dca698824bc0a787b449a95aca5f122e36f54fbc9), uint256(0x1b1bcd4ea07611e949bff691588bda6c70e4e1b0acf3bfef11319f6a00113878)]);
        vk.delta = Pairing.G2Point([uint256(0x0f53ba2fd2e95c8d3edb71660ee161ccf8682dd7c4b864d167697df1007743c2), uint256(0x088351251c7915f08288c8c8054f97d3cd8b03803ba3e6cc914a3d598166a826)], [uint256(0x0080118967d1eecaf09b838bcb603fe5660ae75bcec02604a223dd6f785c7141), uint256(0x22bdbd2cc5cd89825d3f0f155483e775c3bc9ef8193352105ca4105e17e95cdf)]);
        vk.gamma_abc = new Pairing.G1Point[](82);
        vk.gamma_abc[0] = Pairing.G1Point(uint256(0x0a22213544da9740e5158f70735daaa26536b069590182cbd4cfdbf580277a7f), uint256(0x0ed9fd537fe5319a8c3db16296515743bebe02e3a5ab9fcd4a719cdbe164c92b));
        vk.gamma_abc[1] = Pairing.G1Point(uint256(0x1603388a512e5f8cdc06a32f698327e89c39fa41f9e949a0b200d76e1503f2cb), uint256(0x244969a07708c313abec442f3cc2c35cb96b52d027336acfad3c3b30b1ea0115));
        vk.gamma_abc[2] = Pairing.G1Point(uint256(0x2b87aac58d8d294f5e170b4faeb0c84e45c3d009979e13a983720bade5cac138), uint256(0x18756bd8ff029bdf1a1e358c721770d17dee209adbfb0094b7f44026b3941fdd));
        vk.gamma_abc[3] = Pairing.G1Point(uint256(0x0a33f2db96869fbb85737b66a2554e57db9a50cc5d93d43306d4ab0ccadea268), uint256(0x129745305e13197b34cd38c2d4ccec769f37c55e6cb9eefb3007124f7d282a4c));
        vk.gamma_abc[4] = Pairing.G1Point(uint256(0x164bf06bbcd695c11a70471ebbe4287954b304bd12bdd76c3ae755a9d6b9d6d1), uint256(0x1b0f54df89c7c93e9d4d73071432e6d97c32e8dd9654d3343be1e0ad96ba47f6));
        vk.gamma_abc[5] = Pairing.G1Point(uint256(0x2b1c07e038e030b0e9d1dc48785a107a8ab0e705469004cb04474ec6d8c61051), uint256(0x2fa47d14f5786909e0818abb32437646795576b2cfffd40aa529b9103a958e4e));
        vk.gamma_abc[6] = Pairing.G1Point(uint256(0x0a0155dc80c1de5887cc3cc986eca929861649177b24077e2525d7b25afbb9d9), uint256(0x2413719d2b336b07df274d5ed438a431d7f2ea6756fa5375f5a33775755dc801));
        vk.gamma_abc[7] = Pairing.G1Point(uint256(0x0032eb483a3fda947c678630995cf2a888c0a3c695c782fcd01dfb3eeda4c24b), uint256(0x0231157fb2b2da0489d27275939669ea4c487e437192c11469a92dd6b4f536c0));
        vk.gamma_abc[8] = Pairing.G1Point(uint256(0x0e30c48f0c602921e8ddedeab3f3fb673895acff8d32b9ab2f439449cdc870f5), uint256(0x014bc799e9ba6f13b3c917de39144c5727af808cd5ca6250bc47b207acc12e0b));
        vk.gamma_abc[9] = Pairing.G1Point(uint256(0x246d6000b3fa0ba87d5ce609947588513c808e0eaea4740ce9df44811986b09a), uint256(0x12bb1bc9db7f64f81da44eb8c744c52cf03d8121484dfae1b70fa3e96d969bcb));
        vk.gamma_abc[10] = Pairing.G1Point(uint256(0x12daf67353a8acab1159ac343f73f85fcff86c6925dfc5bafbe6d3d2313ebcbe), uint256(0x279096e43e10f91958905ac3edf74d44ec47ed81ffcd12a7ab6ddb15ea956d09));
        vk.gamma_abc[11] = Pairing.G1Point(uint256(0x291820d42c97e317d8b1b9c3a70c68e806dc063f862aec4cc50808635f894931), uint256(0x0d49c0cee277ca6592c9f24e991a3f963c495250a3c49e515788a5b0edb4afc8));
        vk.gamma_abc[12] = Pairing.G1Point(uint256(0x265004575a432267c5e5b64d294230a710b4637a2e6de01616d7096b5a269261), uint256(0x0f3753e453fc8efc0888f6f180c00572a9753a8ec0edd4afed3bb41b675872f6));
        vk.gamma_abc[13] = Pairing.G1Point(uint256(0x0f66b99afaadd860378fdd5b5e9e1fcd97c3b3b56b8628d93bcb9debf6fe816f), uint256(0x1a3d3fe299d18baa0f0a1e31435047c960cd8d21f5b5968d3557e277dbaa40b3));
        vk.gamma_abc[14] = Pairing.G1Point(uint256(0x2837022c61d77f1df935480b01685ffdd3c45b33baa85b298bcc2ad33b873743), uint256(0x0020a528c5b724627e91f18fd793a9c0864347063411ac0420d1ca29adcbaa43));
        vk.gamma_abc[15] = Pairing.G1Point(uint256(0x09757f10d849f6c07223d7d80ea403122e1099ed50a572707914d6cd6b283103), uint256(0x29ec43a9696fa0c89c4d4fc79fa3ad5312c8a281c4c19d15e3ae1db538e39742));
        vk.gamma_abc[16] = Pairing.G1Point(uint256(0x233adbcf98e199343a51756af54af4ced023ed982ea67ba90701cb577ce8d7f0), uint256(0x1758ef2eb5c99243ffd15d0701a816ad2b0a67542653e466089e5a2cf8d7e8cc));
        vk.gamma_abc[17] = Pairing.G1Point(uint256(0x206faf478ccf7ea138f2469059277c4598e591cc5ebc06f7fbe54f690e3f2812), uint256(0x0cad560f8d98c64057f0ec2401b43120dd356282474f0c860ba1473d7fbb171c));
        vk.gamma_abc[18] = Pairing.G1Point(uint256(0x1ca17f36a195db798b636e540c356d0f6e61ea22c58ddde7cf9ff831ce469686), uint256(0x1138a17a13365d3ae3a38471921ff01b54cb676717976b4a8a15139b163cf2ba));
        vk.gamma_abc[19] = Pairing.G1Point(uint256(0x16a1a935d1bda106ffaf7d75719ab2ab396846939e29957e7623764323eb6f7b), uint256(0x281c78f2aa7ecefe7977dedd1c20101a91a165b0b6330cde07309bea371db886));
        vk.gamma_abc[20] = Pairing.G1Point(uint256(0x2c2727454a725e89726baf92f8e7b373df6c16a538f386175b124d703785d83b), uint256(0x03401003808aa25d290263e622fa7bc320c4848edd12aa7df3f51e09d2da7815));
        vk.gamma_abc[21] = Pairing.G1Point(uint256(0x2ca26e48d5d95b239c29a798e0fe9cafffa3218947cb10d27a536514e7c7d61d), uint256(0x0fed1bb9bb58482f3c819c8db902d3aacbcc15477297541f1a043e487d972db1));
        vk.gamma_abc[22] = Pairing.G1Point(uint256(0x02985fd8861f8320f9ba431d3774f78feb3465c589e2ee8308edb5148af3bfdf), uint256(0x12a00aa6c85a3e5c459ea27ec2a9afb4f95ba6ff5b05214a18f6e23d29c869f0));
        vk.gamma_abc[23] = Pairing.G1Point(uint256(0x10f37e8bc55adc6de93060b8135fa90d5b688fd8fcedb1598aa67d68b4dc0cb5), uint256(0x178bff33f39316858dc4272b657716558d84738cd978e747c14fa84ac10e766c));
        vk.gamma_abc[24] = Pairing.G1Point(uint256(0x264cc9a026bc72fd36458eef14cd79d7d3c065b6c5699ee5d38e3ff844857897), uint256(0x03ef0aec0dace53c965ae8639718d58365fe76a88da742f56758263292f3adf2));
        vk.gamma_abc[25] = Pairing.G1Point(uint256(0x1193eae39d3f22ed470f43584a6a77123c051105481eef9f755b21c8e9d5d1e5), uint256(0x24d80c4e9e165ef4f3dce6659b2bc0c80d6857ccf2622e1065997cadb5a0e1ca));
        vk.gamma_abc[26] = Pairing.G1Point(uint256(0x1fcac486d772f7bb57f6c56b7e34a4bf1bc600a4771df9a69b710b10c725e2ed), uint256(0x1ca4af54f95b215810d7f2d1ea7aa738ae31beb770305b6988d8167c9efac3e1));
        vk.gamma_abc[27] = Pairing.G1Point(uint256(0x18a038404ac65b3e705bcf16866e10797a29d75123826d99e63298e5fc68e7c9), uint256(0x14a5d54d1a462365c482c466792aa8c56a38144df2a898a5e70fa5dce5eda870));
        vk.gamma_abc[28] = Pairing.G1Point(uint256(0x1f014ae0fea284948062174816909a0b02e9fda4d68ec173c09208726a7d2681), uint256(0x027e6a97f4c137fa1b4fe32dadc18f0a3fbab60d135419b58dd5195402f6a799));
        vk.gamma_abc[29] = Pairing.G1Point(uint256(0x102058bd5d2093af80d38281d213a5ea9494f282329782d59b1f0b3ebf3136ba), uint256(0x1b72738a5311349fd63f67b10acff7d99ae64127051f6cf05a26e75fc2155a58));
        vk.gamma_abc[30] = Pairing.G1Point(uint256(0x20d2b85a5c7ae2fca50812fd6b611fc8c84b7ee016496d5c97a6440097801ef5), uint256(0x0576446a53e48a9ed216ef022cffc46fa1f1c2b4a56cb1ada3f5ba870b691e6f));
        vk.gamma_abc[31] = Pairing.G1Point(uint256(0x1a514dce0a1af9d85587b8e88c1e9597b8ea340e5e4429c604a8e8b6e735e2d1), uint256(0x0e2b84a86fce95f16558ffd37eabd9471d8d1f9069b73f3f838e7b7f59097e81));
        vk.gamma_abc[32] = Pairing.G1Point(uint256(0x000d0c05bc150de930c9fdd729644bf1aaa794cc0c2be95c6d2abedf2d5c113b), uint256(0x12a1d8fb3feb4b3bb504abc5ab44d43a7b48a4f07ee0695b0bf82b03f5357489));
        vk.gamma_abc[33] = Pairing.G1Point(uint256(0x0cdb538244e19f547baeab9d3afcefa0fd96c567d761d342bfd52b344506eb53), uint256(0x28151d2715db6b18003febbff17172f9dd48ab10ab5b66c3f3ad3cbcd48470c4));
        vk.gamma_abc[34] = Pairing.G1Point(uint256(0x285ffa0bf2e7ce4ccfebe1c42ba3bfbc64e0f200a9be3681ca7d04bb7e37de11), uint256(0x08d7a8949be3172c748705ccd8c3b573249aae88f1fca5ca8e5f8ae016661e1b));
        vk.gamma_abc[35] = Pairing.G1Point(uint256(0x1896ce45025f0994d419d20c95c4d6caa0dbd42418736b8d2fd70c7f7add7461), uint256(0x101d57fe7418a2ceed93901a62e76cec9ad7a90cf88335d229e26dab36f2be68));
        vk.gamma_abc[36] = Pairing.G1Point(uint256(0x1d9be94f9c8217d4d31687b51fbcfd61b716369f1cb20557b559092793ce26b1), uint256(0x0030ebfd35acbf05363d393a99cf756767495670eb92098f1b3c0ada1b7b613b));
        vk.gamma_abc[37] = Pairing.G1Point(uint256(0x160bb5980259865363fc18399ec53003ad037c77b9a0223728b9da494e8a8dcc), uint256(0x0de4d1761807ae76b965e3831147835f264130d5151ff342a046e2a800ed0de6));
        vk.gamma_abc[38] = Pairing.G1Point(uint256(0x281a85d6188a5714c21369d48bce805bd3085923f8eee35c5e64f67e065392d2), uint256(0x1e1b44c68fb2e9e618de534099ff3ff27ee7f60a27a14ce1c994a56bb99c40da));
        vk.gamma_abc[39] = Pairing.G1Point(uint256(0x17dcbf881d21160ed077ef9b7a31696f1a3a18a2a960a00834c60a798a22552d), uint256(0x0fc6049a4e8e3b32d4f15097db743938b9cfa65e90564a0910ca6214a05cbe8f));
        vk.gamma_abc[40] = Pairing.G1Point(uint256(0x1b901a007b7d47ae5a98b62411506786f7927e4e52951fd0ca8c76835017e918), uint256(0x27fa6d1a3f8067910548bd2d29f0155d522e72e368a25e15356130a92dc9799d));
        vk.gamma_abc[41] = Pairing.G1Point(uint256(0x0ac6380e0667c41956c7702cca08526771836f86729e615496934619085e8d3d), uint256(0x17d78a50a38236b6ea507e2cbd46d8fd046c8cf641f964951deec30d885cbc61));
        vk.gamma_abc[42] = Pairing.G1Point(uint256(0x0aa292ceb356d951449c3b06b8f48d7ff277e59de5860981e148950260e1f45c), uint256(0x29533caef109d03be0e19ba8123e7288dcccbf13227a6a91cb8bdeef94c0484c));
        vk.gamma_abc[43] = Pairing.G1Point(uint256(0x217845c780a4fb07a271548017e0409401a123dcfabfcaa03c1a4e0a413a4245), uint256(0x03c0ade006006355ae12a0b1a0d600b15f71ba2de62d5271a6286a16a5f49e28));
        vk.gamma_abc[44] = Pairing.G1Point(uint256(0x1f6def7630013424e1cf360dd7c52b38d51272da1b3484ce0c0d738c15058fae), uint256(0x122d6edf1e908c7d782c04764ee1c8d804089e2a5af38f2274e9d40025d60715));
        vk.gamma_abc[45] = Pairing.G1Point(uint256(0x13c6828b8bcad931374871be588d6057139d5b8f5a6bebb1985ebedbb345901d), uint256(0x00e0f8d0ce99ac251d5bedff8f24a31e802e0b42374de5fc5e0b6d36c825600d));
        vk.gamma_abc[46] = Pairing.G1Point(uint256(0x2304fb2ba2f72624f961225eebb0a741b9582bcc9adb0ef4fd7df06ead820c57), uint256(0x283384ebe51900c5c8eb49c704102767a58fe60c10980767c6329bdc6942259c));
        vk.gamma_abc[47] = Pairing.G1Point(uint256(0x2a4b2555b216b071f953f1a6ad01b4224fd4a4c30ac1862b43bd58e8ee5eb75f), uint256(0x1e2088fa20246d41b46955ab2d99114f90683568c1afd6978ba8c0339ba183f4));
        vk.gamma_abc[48] = Pairing.G1Point(uint256(0x1d958bb84b792227555b03cd48177bbf82a5c7214afbe5ae1b27aff227a5f127), uint256(0x02f415f183664e5519c1dd6a03d8edb8f8135c26dc7de203216d03703b987208));
        vk.gamma_abc[49] = Pairing.G1Point(uint256(0x1c08dc3f0e8eb8ed9b8ef3ed147ccd353944fce2fee01a6f4356ef4342a9c500), uint256(0x03e1717884270bf866284c4740cca77656afef65c365b6646178d326d704f24e));
        vk.gamma_abc[50] = Pairing.G1Point(uint256(0x0c502ce1ea804fe45c25ab36c563969c0785bfb8c276a0bff2c9d68d1b7776f9), uint256(0x1d59fb8a4e6bf26cd13936b6b69391151b3c524c716039cc8bdf881099e361cd));
        vk.gamma_abc[51] = Pairing.G1Point(uint256(0x1b7b4595f9eae31cb3a44c71821c39a868afa6e64c8299b6a6db79e91aca014a), uint256(0x2e35d059a11135bf5ccbb051fc4494e562acb9a6f2a266c8a1c08ea221388b2a));
        vk.gamma_abc[52] = Pairing.G1Point(uint256(0x104291a0934c6cb4a8a8af3125e4d5b0ed8602c33b1a5218c9d7547e07945e11), uint256(0x1b307acceab63577c1b6d0197e919aaaa4a1a32c2fcf9370c5ad3cf6b6ba7933));
        vk.gamma_abc[53] = Pairing.G1Point(uint256(0x0c5670e2a22f3ce6e215f3b47b655802cbc3d8f195f348f0e38564cf69fec708), uint256(0x10b28bdd5ca11317ffdba451000ea063120457f14bd7601934b94bd128ca3b8f));
        vk.gamma_abc[54] = Pairing.G1Point(uint256(0x19f3535b7d731559684b8a3dc2305b7aeb3f625021e8cf3eabc2fb71b624d201), uint256(0x254523ea95e25f41469bf28b4babb4a14268140a8eaa6c289e53bbd4605d9d7f));
        vk.gamma_abc[55] = Pairing.G1Point(uint256(0x270b57c96b6970f75f0f8fed768d4531301a8f75d213966c968c3c17e764a2f4), uint256(0x1907e120bb0fc01f2da34eaa117e88211683e4b78486bfb229fef6b2fe542a64));
        vk.gamma_abc[56] = Pairing.G1Point(uint256(0x0bc5c753426681318cf44ad436a81edb0609eac5520f5d1084e89b34b90455ce), uint256(0x04f8c880bade08996fbfe33212c8acd49c87e398e6a74aeb6626f0343a7ebfd5));
        vk.gamma_abc[57] = Pairing.G1Point(uint256(0x1089293fece7fe91f41d6830bc0f50ddb549d5eb85f6af7e330392a6194fa6bf), uint256(0x02c712d56f17f3580b373affb80eeda528661fa538d626611a4ab9c66a045587));
        vk.gamma_abc[58] = Pairing.G1Point(uint256(0x079cec833535a07d4e9348a60b7e5de124ce71b6949a7570e731095012322ead), uint256(0x136e7d4085f5665d224d6a973f408113a4f42105c3b87089b8f3856183c980b4));
        vk.gamma_abc[59] = Pairing.G1Point(uint256(0x22c108383cc42d831423b2ec4158b258af6a1c41b482b9803372e4422637eed7), uint256(0x229a4da51b0ba6bde44cf162fd893e3d095cc13d66caf4540818ac9c6c6d8699));
        vk.gamma_abc[60] = Pairing.G1Point(uint256(0x208f55fd9994f8122b4a671bd78a17442fc2f7821dd33304dc26649363bd6a32), uint256(0x0679fb17654ef8bf5237ba5763ac7fa54a6f1628f0ea5ca0a7b0216600bc0720));
        vk.gamma_abc[61] = Pairing.G1Point(uint256(0x29d65ff22fac605bec636d37c5d26c88834509e77ed6e0d92cba754746a62725), uint256(0x099293b9bf8e413b72b2c6b690a37a913867e40b242c91d3654ec19f59a35c49));
        vk.gamma_abc[62] = Pairing.G1Point(uint256(0x172525d2aab25c1287ccdf8153bd1316b09241caa3f9ed7106afbcbc49e8ee58), uint256(0x2b8ef689880582a193bddc1b11c973b1a3856f6553e38c6a2d855f1b6f213b5c));
        vk.gamma_abc[63] = Pairing.G1Point(uint256(0x2b55ce41811b82a3ab8543fc2b869ada40b2d9f1f76bbf4423dbc32a7e95a58b), uint256(0x2c073a5c33b2207f64c724fdb896ca498214c7414d19285e43e579d941361c6d));
        vk.gamma_abc[64] = Pairing.G1Point(uint256(0x22890f0eaba8354ce95fe7f9f46958f8393e95914a73e665599630547ba3ccd9), uint256(0x08bc40aff32532009756cc745596e1bba198d06779fe181e07ef1579726af2bd));
        vk.gamma_abc[65] = Pairing.G1Point(uint256(0x0324fb236c0a38c46f33db0da158fb9be1c2f23d3aaa382e170b52576e1aea6d), uint256(0x0b487578b2abe61c5e627dba9021db807c32b62db2b1ffa2876f9e0a96e9aa8b));
        vk.gamma_abc[66] = Pairing.G1Point(uint256(0x1edd3c85805f5eda179afd6823b72f6ff510aaa619e6b5d1100ede6ebf68b8fe), uint256(0x04cb88cbddebac182abedbb3d0296e9e4a3d08c5c25cbf51167c5d3c853940e4));
        vk.gamma_abc[67] = Pairing.G1Point(uint256(0x1863d1dddce104848b6c3d854b1408580cc4038b48bab0ffeac9fe2b6bbb1eca), uint256(0x1a61984d5aaabb5ad013ba73a7763ab1d8151656a433be7b0bc89ab6fbbf94f8));
        vk.gamma_abc[68] = Pairing.G1Point(uint256(0x288ed9a86d35c84c72108d1f3bcd0565ff66a91635293b6e508e2367c7da68f9), uint256(0x2757500f3f1ea31a6bc2d299b6f048fc3a578eef0eadc13b5cb8caf30d159553));
        vk.gamma_abc[69] = Pairing.G1Point(uint256(0x1738c89054ab2df98fd44637668a86153141ce5a8fa89e73e2ba2d77c35d4142), uint256(0x27fc20d1409585f361de3e0e0d37ff986c73be942345b1663cd94670bd4454b4));
        vk.gamma_abc[70] = Pairing.G1Point(uint256(0x0c69f17246069f861b87402ce67449154f61f4fb8feec9a456608476bdb57c04), uint256(0x2284f65dd623be3596449381777eaaea7adadf0dbef9178bbbb187ce9a225b27));
        vk.gamma_abc[71] = Pairing.G1Point(uint256(0x104f6ca5149e73cd2d3ee6b2a41a3c5ccd24b4892c118f1b955386e71257296a), uint256(0x1d1828acc41c1b5fa3bf933a812b1cf4df282a5b449c3b8583b4d5e897a26b95));
        vk.gamma_abc[72] = Pairing.G1Point(uint256(0x08a82ef692ecbe57a09ee8a2b8b59954405146b38d448aef178bdd9256680cfc), uint256(0x2915066fdd0a00a6a25212ff8d209dfa08c97dab4b542788505f49153c0a144b));
        vk.gamma_abc[73] = Pairing.G1Point(uint256(0x0a626e913bc8c69c2cc1e3b49ed285d5a695eea3bc6ebbc93443178c066c3b12), uint256(0x24a856adbb3cceec04db4a37329b19b06189c5496983a286fc8a6525fb9e36e9));
        vk.gamma_abc[74] = Pairing.G1Point(uint256(0x299466da98ec479f59defbf48df6f5e1f62fb20f50a3771cf84466a136817002), uint256(0x2b2c974e446305b038ffcdd88b1d0fe655ecf3ebaae257351e683e1d7f3817f8));
        vk.gamma_abc[75] = Pairing.G1Point(uint256(0x250c3bb0a8862cf3ff464a008db3e049a9097edc3eac216d283f1c8b74df2cc5), uint256(0x05a0820ea3feda985ceca7b74d21f484182fcdd0c697f92f87ceaac83af73196));
        vk.gamma_abc[76] = Pairing.G1Point(uint256(0x184384e9df5a6da8ce1c3e2039ae0316b568322203ecb9505624d8340aaa0ac0), uint256(0x2dd45e10b9c84af5a6f539d6b6e2a60db0d572e4756fee0179534d3a326897a8));
        vk.gamma_abc[77] = Pairing.G1Point(uint256(0x0a4539737a52cffc80a4a508926697474f1a80e5de15827b860c590f62ea39ca), uint256(0x0d86a34617ee7d0735cce9dad542f83bd6dd498bf3a9ab500c25cfade07aee4f));
        vk.gamma_abc[78] = Pairing.G1Point(uint256(0x023cb508752bc2b4c606a9f115ce5692ac4666f97c4bd1d20e39dd2a1d7d3a1a), uint256(0x1e4eb2af76d75edaa5025316e2b3cfaeb33b25c33424074dfe36d2309ec3deec));
        vk.gamma_abc[79] = Pairing.G1Point(uint256(0x17e983d1595e6bb4f9d3db8bcee76b1d5280e6f5cfa8d04b9ba7739884d149a7), uint256(0x23793bc75fbfd7cf645caaa28afb7b2be8910e5f411a70d6e82d6a29c438f0fe));
        vk.gamma_abc[80] = Pairing.G1Point(uint256(0x185ec25936febc1bbff4c46ec9b0c402aa3b513e2a183a8d753e41d86634297f), uint256(0x06c4ac8fc12185e6381a9bcb895738853a31364c0c0015f760066d64eddeab97));
        vk.gamma_abc[81] = Pairing.G1Point(uint256(0x24e9efed8bff93ab2494f5520b74b68b8965bed1c8c4d9a21437ea53ec43ab91), uint256(0x23665dfd6438783f82a3450880de07d7e51fe9594585270397873015fd1c027b));
    }
    function verify(uint[] memory input, Proof memory proof) internal view returns (uint) {
        uint256 snark_scalar_field = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        VerifyingKey memory vk = verifyingKey();
        require(input.length + 1 == vk.gamma_abc.length);
        // Compute the linear combination vk_x
        Pairing.G1Point memory vk_x = Pairing.G1Point(0, 0);
        for (uint i = 0; i < input.length; i++) {
            require(input[i] < snark_scalar_field);
            vk_x = Pairing.addition(vk_x, Pairing.scalar_mul(vk.gamma_abc[i + 1], input[i]));
        }
        vk_x = Pairing.addition(vk_x, vk.gamma_abc[0]);
        if(!Pairing.pairingProd4(
             proof.a, proof.b,
             Pairing.negate(vk_x), vk.gamma,
             Pairing.negate(proof.c), vk.delta,
             Pairing.negate(vk.alpha), vk.beta)) return 1;
        return 0;
    }
    function verifyTx(
            Proof memory proof, uint[81] memory input
        ) public view returns (bool r) {
        uint[] memory inputValues = new uint[](81);
        
        for(uint i = 0; i < input.length; i++){
            inputValues[i] = input[i];
        }
        if (verify(inputValues, proof) == 0) {
            return true;
        } else {
            return false;
        }
    }
}
