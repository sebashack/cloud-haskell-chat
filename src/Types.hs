{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE DeriveGeneric      #-}

module Types where

import GHC.Generics
import Data.Binary
import Data.Typeable.Internal
import Control.Distributed.Process (Process, ProcessId)


data Sender = Server | Client String
  deriving (Generic, Typeable, Eq, Show)

instance Binary Sender


data ChatMessage = ChatMessage {
    from :: Sender
  , message :: String
  } deriving (Generic, Typeable, Show)

instance Binary ChatMessage


newtype JoinChatMessage = JoinChatMessage {
    clientName :: String
  } deriving (Generic, Typeable, Show)

instance Binary JoinChatMessage
