module DataTypes exposing (AllMapsParties, MapType(..), Party(..), allMapsPartiesDecoder, defaultAllMapsParties, encodeAllMapsParties, encodePartyString, mapTypeToString, partyDecoder, partyStringDecoder)

import Array exposing (Array)
import Json.Decode as D exposing (Decoder)
import Json.Encode as E exposing (Value)


type Party
    = Republican
    | Democrat


type alias AllMapsParties =
    { senateParties : Array Party
    , houseParties : Array Party
    , congressParties : Array Party

    -- , educationParties : Array Party
    }


type MapType
    = Senate
    | House
    | Congress



-- | Education


mapTypeToString : MapType -> String
mapTypeToString mapType =
    case mapType of
        Senate ->
            "senate"

        House ->
            "house"

        Congress ->
            "congress"



-- Education ->
-- "education"


districtCount : MapType -> Int
districtCount mapType =
    case mapType of
        Senate ->
            31

        House ->
            150

        Congress ->
            36



-- Education ->
--     15


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


encodePartyString : Array Party -> Value
encodePartyString =
    Array.toList
        >> List.map
            (\party ->
                case party of
                    Democrat ->
                        "D"

                    Republican ->
                        "R"
            )
        >> String.concat
        >> E.string


partyStringOrDefaultDecoder : MapType -> Decoder (Array Party)
partyStringOrDefaultDecoder mapType =
    D.maybe partyStringDecoder
        |> D.andThen
            (\maybeParties ->
                case maybeParties of
                    Nothing ->
                        D.succeed (defaultParties mapType)

                    Just parties ->
                        if Array.length parties == districtCount mapType then
                            D.succeed parties

                        else
                            D.succeed (defaultParties mapType)
            )


defaultParties : MapType -> Array Party
defaultParties mapType =
    Array.initialize (districtCount mapType) (always Republican)


defaultAllMapsParties : AllMapsParties
defaultAllMapsParties =
    { senateParties = defaultParties Senate
    , houseParties = defaultParties House
    , congressParties = defaultParties Congress

    -- , educationParties = defaultParties Education
    }


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


allMapsPartiesDecoder : Decoder AllMapsParties
allMapsPartiesDecoder =
    D.map3
        (\senate house congress ->
            { senateParties = senate
            , houseParties = house
            , congressParties = congress

            -- , educationParties = education
            }
        )
        (D.field "senate" (partyStringOrDefaultDecoder Senate))
        (D.field "house" (partyStringOrDefaultDecoder House))
        (D.field "congress" (partyStringOrDefaultDecoder Congress))



-- (D.field "education" (partyStringOrDefaultDecoder Education))


encodeAllMapsParties : AllMapsParties -> Value
encodeAllMapsParties parties =
    E.object
        [ ( "senate", encodePartyString parties.senateParties )
        , ( "house", encodePartyString parties.houseParties )
        , ( "congress", encodePartyString parties.congressParties )

        -- , ( "education", encodePartyString parties.educationParties )
        ]
