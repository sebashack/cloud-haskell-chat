module Main where

import Server

main :: IO ()
main = putStrLn "Chat server running ..." >> server
