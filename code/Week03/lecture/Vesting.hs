{-# LANGUAGE DataKinds         #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell   #-}

module Vesting where

import           Data.Maybe                (fromJust)
import           Plutus.V1.Ledger.Interval (contains)
import           Plutus.V2.Ledger.Api      (BuiltinData, POSIXTime, PubKeyHash,
                                            ScriptContext (scriptContextTxInfo),
                                            TxInfo (txInfoValidRange),
                                            Validator, from, mkValidatorScript)
import           Plutus.V2.Ledger.Contexts (txSignedBy)
import           PlutusTx                  (compile, unstableMakeIsData)
import           PlutusTx.Prelude          (Bool, traceIfFalse, ($), (&&), error, (==), otherwise)
import           Prelude                   (IO, String)
import           Utilities                 (Network, posixTimeFromIso8601,
                                            printDataToJSON,
                                            validatorAddressBech32, wrap,
                                            writeValidatorToFile)

---------------------------------------------------------------------------------------------------
----------------------------------- ON-CHAIN / VALIDATOR ------------------------------------------

data VestingDatum = VestingDatum
    { beneficiary :: PubKeyHash
    , deadline    :: POSIXTime
    }

unstableMakeIsData ''VestingDatum

{-# INLINABLE mkVestingValidator #-}
mkVestingValidator :: VestingDatum -> () -> ScriptContext -> Bool
mkVestingValidator dat () ctx = traceIfFalse "beneficiary's signature missing" signedByBeneficiary &&
                                traceIfFalse "deadline not reached" deadlineReached
  where
    info :: TxInfo
    info = scriptContextTxInfo ctx

    signedByBeneficiary :: Bool
    signedByBeneficiary = txSignedBy info $ beneficiary dat

    deadlineReached :: Bool
    deadlineReached = contains (from $ deadline dat) $ txInfoValidRange info

{-# INLINABLE tbsTest #-}
tbsTest :: BuiltinData -> BuiltinData -> BuiltinData -> ()
tbsTest datum  redeemer _ 
 | datum == redeemer   = ()
 | otherwise           = error ()

{-# INLINABLE  mkWrappedVestingValidator #-}
mkWrappedVestingValidator :: BuiltinData -> BuiltinData -> BuiltinData -> ()
mkWrappedVestingValidator = wrap mkVestingValidator



validator :: Validator
validator = mkValidatorScript $$(compile [|| mkWrappedVestingValidator ||])

tbsValidator :: Validator
tbsValidator = mkValidatorScript $$(compile [|| tbsTest ||])
---------------------------------------------------------------------------------------------------
------------------------------------- HELPER FUNCTIONS --------------------------------------------

saveVal :: IO ()
saveVal = writeValidatorToFile "./assets/vesting.plutus" validator

creaTBSplutus :: IO ()
creaTBSplutus =  writeValidatorToFile "./testnet/tbsTest.plutus" validator

vestingAddressBech32 :: Network -> String
vestingAddressBech32 network = validatorAddressBech32 network validator

printVestingDatumJSON :: PubKeyHash -> String -> IO ()
printVestingDatumJSON pkh time = printDataToJSON $ VestingDatum
    { beneficiary = pkh
    , deadline    = fromJust $ posixTimeFromIso8601 time
    }
