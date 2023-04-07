unit-test-LinearCurve:
	forge test --match-path test/unit/LinearCurve.t.sol -vvv

unit-test-LinearBondingCurve:
	forge test --match-path test/unit/LinearBondingCurve.purchase.t.sol -vvv

unit-test-BondingCurveAsOwner:
	forge test --match-path test/unit/BondingCurve.owner.t.sol -vvv

# audit
coverage:
	forge coverage --report lcov && genhtml lcov.info --branch-coverage --output-dir coverage