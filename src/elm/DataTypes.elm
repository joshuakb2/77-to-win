module DataTypes exposing (AllMapsParties, MapType(..), Party(..), allMapsPartiesDecoder, defaultAllMapsParties, defaultParties, encodeAllMapsParties, encodePartyString, mapTypeToString, partyDecoder, partyStringDecoder)

import Array exposing (Array)
import Json.Decode as D exposing (Decoder)
import Json.Encode as E exposing (Value)


type Party
    = Republican
    | Democrat


type alias AllMapsParties =
    { senateParties : Maybe (Array Party)
    , houseParties : Maybe (Array Party)
    , congressParties : Maybe (Array Party)

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



-- partyStringOrDefaultDecoder : MapType -> Decoder (Array Party)
-- partyStringOrDefaultDecoder mapType =
--     D.maybe partyStringDecoder
--         |> D.andThen
--             (\maybeParties ->
--                 case maybeParties of
--                     Nothing ->
--                         D.succeed (defaultParties mapType)
--                     Just parties ->
--                         if Array.length parties == districtCount mapType then
--                             D.succeed parties
--                         else
--                             D.succeed (defaultParties mapType)
--             )


defaultParties : MapType -> Array Party
defaultParties mapType =
    case mapType of
        Senate ->
            currentSenate

        House ->
            currentHouse

        Congress ->
            currentCongress


defaultAllMapsParties : AllMapsParties
defaultAllMapsParties =
    { senateParties = Nothing
    , houseParties = Nothing
    , congressParties = Nothing

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
        (D.field "senate" (D.nullable partyStringDecoder))
        (D.field "house" (D.nullable partyStringDecoder))
        (D.field "congress" (D.nullable partyStringDecoder))



-- (D.field "education" (partyStringOrDefaultDecoder Education))


encodeAllMapsParties : AllMapsParties -> Value
encodeAllMapsParties parties =
    E.object
        [ ( "senate", encodeMaybe encodePartyString parties.senateParties )
        , ( "house", encodeMaybe encodePartyString parties.houseParties )
        , ( "congress", encodeMaybe encodePartyString parties.congressParties )

        -- , ( "education", encodePartyString parties.educationParties )
        ]


encodeMaybe : (a -> Value) -> Maybe a -> Value
encodeMaybe encode maybeA =
    case maybeA of
        Just a ->
            encode a

        Nothing ->
            E.null


currentSenate : Array Party
currentSenate =
    Array.fromList
        [ Republican -- 1
        , Republican -- 2
        , Republican -- 3
        , Republican -- 4
        , Republican -- 5
        , Democrat -- 6
        , Republican -- 7
        , Republican -- 8
        , Republican -- 9
        , Democrat -- 10
        , Republican -- 11
        , Republican -- 12
        , Democrat -- 13
        , Democrat -- 14
        , Democrat -- 15
        , Democrat -- 16
        , Republican -- 17
        , Republican -- 18
        , Republican -- 19
        , Democrat -- 20
        , Democrat -- 21
        , Republican -- 22
        , Democrat -- 23
        , Republican -- 24
        , Republican -- 25
        , Democrat -- 26
        , Democrat -- 27
        , Republican -- 28
        , Democrat -- 29
        , Republican -- 30
        , Republican -- 31
        ]


currentHouse : Array Party
currentHouse =
    Array.fromList
        [ Republican -- 1
        , Republican -- 2
        , Republican -- 3
        , Republican -- 4
        , Republican -- 5
        , Republican -- 6
        , Republican -- 7
        , Republican -- 8
        , Republican -- 9
        , Republican -- 10
        , Republican -- 11
        , Republican -- 12
        , Republican -- 13
        , Republican -- 14
        , Republican -- 15
        , Republican -- 16
        , Republican -- 17
        , Republican -- 18
        , Republican -- 19
        , Republican -- 20
        , Republican -- 21
        , Democrat -- 22
        , Republican -- 23
        , Republican -- 24
        , Republican -- 25
        , Republican -- 26
        , Democrat -- 27
        , Republican -- 28
        , Republican -- 29
        , Republican -- 30
        , Democrat -- 31
        , Republican -- 32
        , Republican -- 33
        , Democrat -- 34
        , Democrat -- 35
        , Democrat -- 36
        , Democrat -- 37
        , Democrat -- 38
        , Democrat -- 39
        , Democrat -- 40
        , Democrat -- 41
        , Democrat -- 42
        , Republican -- 43
        , Republican -- 44
        , Democrat -- 45
        , Democrat -- 46
        , Democrat -- 47
        , Democrat -- 48
        , Democrat -- 49
        , Democrat -- 50
        , Democrat -- 51
        , Democrat -- 52
        , Republican -- 53
        , Republican -- 54
        , Republican -- 55
        , Republican -- 56
        , Republican -- 57
        , Republican -- 58
        , Republican -- 59
        , Republican -- 60
        , Republican -- 61
        , Republican -- 62
        , Republican -- 63
        , Republican -- 64
        , Democrat -- 65
        , Republican -- 66
        , Republican -- 67
        , Republican -- 68
        , Republican -- 69
        , Republican -- 70
        , Republican -- 71
        , Republican -- 72
        , Republican -- 73
        , Democrat -- 74
        , Democrat -- 75
        , Democrat -- 76
        , Democrat -- 77
        , Democrat -- 78
        , Democrat -- 79
        , Democrat -- 80
        , Republican -- 81
        , Republican -- 82
        , Republican -- 83
        , Republican -- 84
        , Republican -- 85
        , Republican -- 86
        , Republican -- 87
        , Republican -- 88
        , Republican -- 89
        , Democrat -- 90
        , Republican -- 91
        , Republican -- 92
        , Republican -- 93
        , Republican -- 94
        , Democrat -- 95
        , Republican -- 96
        , Republican -- 97
        , Republican -- 98
        , Republican -- 99
        , Democrat -- 100
        , Democrat -- 101
        , Democrat -- 102
        , Democrat -- 103
        , Democrat -- 104
        , Democrat -- 105
        , Republican -- 106
        , Democrat -- 107
        , Republican -- 108
        , Democrat -- 109
        , Democrat -- 110
        , Democrat -- 111
        , Republican -- 112
        , Democrat -- 113
        , Democrat -- 114
        , Democrat -- 115
        , Democrat -- 116
        , Democrat -- 117
        , Democrat -- 118
        , Democrat -- 119
        , Democrat -- 120
        , Republican -- 121
        , Republican -- 122
        , Democrat -- 123
        , Democrat -- 124
        , Democrat -- 125
        , Republican -- 126
        , Republican -- 127
        , Republican -- 128
        , Republican -- 129
        , Republican -- 130
        , Democrat -- 131
        , Democrat -- 132
        , Republican -- 133
        , Republican -- 134
        , Democrat -- 135
        , Democrat -- 136
        , Democrat -- 137
        , Republican -- 138
        , Democrat -- 139
        , Democrat -- 140
        , Democrat -- 141
        , Democrat -- 142
        , Democrat -- 143
        , Democrat -- 144
        , Democrat -- 145
        , Democrat -- 146
        , Democrat -- 147
        , Democrat -- 148
        , Democrat -- 149
        , Republican -- 150
        ]


currentCongress : Array Party
currentCongress =
    Array.fromList
        [ Republican -- 1
        , Republican -- 2
        , Republican -- 3
        , Republican -- 4
        , Republican -- 5
        , Republican -- 6
        , Democrat -- 7
        , Republican -- 8
        , Democrat -- 9
        , Republican -- 10
        , Republican -- 11
        , Republican -- 12
        , Republican -- 13
        , Republican -- 14
        , Democrat -- 15
        , Democrat -- 16
        , Republican -- 17
        , Democrat -- 18
        , Republican -- 19
        , Democrat -- 20
        , Republican -- 21
        , Republican -- 22
        , Republican -- 23
        , Republican -- 24
        , Republican -- 25
        , Republican -- 26
        , Republican -- 27
        , Democrat -- 28
        , Democrat -- 29
        , Democrat -- 30
        , Republican -- 31
        , Democrat -- 32
        , Democrat -- 33
        , Democrat -- 34
        , Democrat -- 35
        , Republican -- 36
        ]
