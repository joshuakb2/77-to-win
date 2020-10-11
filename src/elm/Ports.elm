port module Ports exposing (consoleError, setDistrictParty, writeLocalStorage)

import DataTypes exposing (Party, partyDecoder)
import Json.Decode as D exposing (Decoder)
import Json.Encode as E exposing (Value)


port writeLocalStoragePort : Value -> Cmd msg


port consoleErrorPort : Value -> Cmd msg


port setDistrictPartyPort : (Value -> msg) -> Sub msg


writeLocalStorage : String -> Value -> Cmd msg
writeLocalStorage name data =
    writeLocalStoragePort <|
        E.object
            [ ( "name", E.string name )
            , ( "data", data )
            ]


fork : (ok -> a) -> (err -> a) -> Result err ok -> a
fork onOk onErr result =
    case result of
        Ok val ->
            onOk val

        Err err ->
            onErr err


consoleError : Value -> Cmd msg
consoleError =
    consoleErrorPort


setDistrictParty : (( Int, Party ) -> msg) -> (D.Error -> msg) -> Sub msg
setDistrictParty onSuccess onProgrammerError =
    setDistrictPartyPort <|
        fork onSuccess onProgrammerError
            << D.decodeValue setDistrictPartyDecoder


setDistrictPartyDecoder : Decoder ( Int, Party )
setDistrictPartyDecoder =
    D.map2 Tuple.pair
        (D.field "districtNum" D.int |> D.map decrement)
        (D.field "newParty" partyDecoder)


decrement : Int -> Int
decrement n =
    n - 1