{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE DeriveGeneric      #-}

module Types where

import GHC.Generics
import Data.Binary
import Data.Typeable.Internal
import Control.Distributed.Process (say, Process, ProcessId)

newtype Message = Message { unMessage :: String }
  deriving (Generic, Typeable, Show)

instance Binary Message

logMessage :: Message -> Process ()
logMessage = say . unMessage


data JoinChatMessage = JoinChatMessage {
    clientName :: String
  , clientPid :: ProcessId
  } deriving (Generic, Typeable, Show)

instance Binary JoinChatMessage
