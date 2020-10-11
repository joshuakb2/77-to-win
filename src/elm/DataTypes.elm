module DataTypes exposing (Party(..), partyDecoder, partyStringDecoder)

import Array exposing (Array)
import Json.Decode as D exposing (Decoder)


type Party
    = Republican
    | Democrat


partyDecoder : Decoder Party
partyDecoder =
    D.string
        |> D.andThen
            (\s ->
                case s of
                    "republican" ->
                        D.succeed Republican

                    "democrat" ->
                        D.succeed Democrat

                    _ ->
                        D.fail ("Expected \"democrat\" or \"republican\" but got \"" ++ s ++ "\"")
            )


partyStringDecoder : Decoder (Array Party)
partyStringDecoder =
    D.string
        |> D.andThen decodePartyList
        |> D.map Array.fromList


decodePartyList : String -> Decoder (List Party)
decodePartyList s =
    case String.uncons s of
        Nothing ->
            D.succeed []

        Just ( c, rest ) ->
            let
                party =
                    if c == 'R' then
                        Just Republican

                    else if c == 'D' then
                        Just Democrat

                    else
                        Nothing
            in
            case party of
                Just p ->
                    decodePartyList rest |> D.map ((::) p)

                Nothing ->
                    D.fail ("Expected 'D' or 'R' but got '" ++ String.fromChar c ++ "'")
