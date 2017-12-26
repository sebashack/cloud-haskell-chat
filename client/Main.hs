module Main where

import Client
import Server (backend)

main :: IO ()
main = backend >>= launchChatClient
