{-# LANGUAGE RecordWildCards     #-}
{-# LANGUAGE ScopedTypeVariables #-}
module Network.Ethereum.Transaction where

-- |
-- Module      :  Network.Ethereum.Transaction
-- Copyright   :  Alexander Krupenkin 2018
--                Roy Blankman 2018
-- License     :  BSD3
--
-- Maintainer  :  mail@akru.me
-- Stability   :  experimental
-- Portability :  unportable
--

import           Data.ByteArray             (ByteArray, convert)
import           Data.ByteString            (ByteString)
import           Data.Maybe                 (fromJust, fromMaybe)
import           Data.RLP                   (packRLP, rlpEncode)
import           Data.Word                  (Word8)

import           Data.ByteArray.HexString   (toBytes)
import           Data.Solidity.Prim.Address (toHexString)
import           Network.Ethereum.Api.Types (Call (..), Quantity (unQuantity))
import           Network.Ethereum.Unit      (Shannon, toWei)

-- | Ethereum transaction codec.
--
-- Two way RLP encoding of Ethereum transaction: for unsigned and signed.
-- Packing scheme described in https://github.com/ethereum/EIPs/blob/master/EIPS/eip-155.md
encodeTransaction :: ByteArray ba
                  => Call
                  -- ^ Transaction call
                  -> Integer
                  -- ^ Chain ID
                  -> Maybe (Integer, Integer, Word8)
                  -- ^ Should contain signature when transaction signed
                  -> ba
                  -- ^ RLP encoded transaction
encodeTransaction Call{..} chain_id rsv = do
    let (to       :: ByteString) = maybe mempty (toBytes . toHexString) callTo
        (value    :: Integer)    = unQuantity $ fromJust callValue
        (nonce    :: Integer)    = unQuantity $ fromJust callNonce
        (gasPrice :: Integer)    = maybe defaultGasPrice unQuantity callGasPrice
        (gasLimit :: Integer)    = unQuantity $ fromJust callGas
        (input    :: ByteString) = convert $ fromMaybe mempty callData

    convert . packRLP $ case rsv of
        -- Unsigned transaction by EIP155
        Nothing        -> rlpEncode (nonce, gasPrice, gasLimit, to, value, input, chain_id, 0 :: Int, 0 :: Int)
        -- Signed transaction
        Just (r, s, v) ->
            let v' = v + 8 + 2 * fromInteger chain_id  -- Improved 'v' according to EIP155
             in rlpEncode (nonce, gasPrice, gasLimit, to, value, input, v', r, s)
  where
    defaultGasPrice = toWei (10 :: Shannon)
