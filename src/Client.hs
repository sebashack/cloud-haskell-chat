module Client where

import Control.Distributed.Process.ManagedProcess.Client (callChan)
import Control.Distributed.Process ( Process
                                   , ProcessId
                                   , ReceivePort )


-- Client code
add :: ProcessId -> String -> Process (ReceivePort String)
add sid msg = callChan sid msg
