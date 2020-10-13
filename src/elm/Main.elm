module Main exposing (main)

import Array exposing (Array)
import Browser exposing (Document, UrlRequest(..), application)
import Browser.Dom exposing (Element)
import Browser.Navigation as Nav
import DataTypes exposing (AllMapsParties, MapType(..), Party(..), allMapsPartiesDecoder, defaultAllMapsParties, encodeAllMapsParties, mapTypeToString)
import Element exposing (Attribute, Color, Element, el, text)
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Html
import Html.Attributes exposing (attribute)
import Json.Decode as D exposing (Decoder, Value)
import Json.Encode as E
import Ports exposing (consoleError, setDistrictParty, windowResized, writeLocalStorage)
import Url exposing (Url)


main : Program Value Model Msg
main =
    application
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        , onUrlRequest = onUrlRequest
        , onUrlChange = onUrlChange
        }


type Model
    = FatalError String
    | Normal NormalModel


type alias NormalModel =
    { key : Nav.Key
    , windowWidth : Int
    , currentUrl : Url
    , mapType : MapType
    , parties : AllMapsParties
    }


type Msg
    = DistrictPartyChanged Int Party
    | MapChosen MapType
    | WindowResized Int
    | FatalErrorOccurred String
    | Noop String


flagDecoder : Decoder ( Int, AllMapsParties )
flagDecoder =
    D.map2 Tuple.pair
        (D.field "width" D.int)
        (onDecoderFail defaultAllMapsParties (D.field "parties" allMapsPartiesDecoder))


onDecoderFail : a -> Decoder a -> Decoder a
onDecoderFail default decoder =
    D.oneOf [ decoder, D.succeed default ]


init : Value -> Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        mapType =
            Senate
    in
    case D.decodeValue flagDecoder flags of
        Ok ( width, parties ) ->
            ( Normal
                { key = key
                , windowWidth = width
                , currentUrl = url
                , mapType = mapType
                , parties = parties
                }
            , Cmd.none
            )

        Err err ->
            ( FatalError "Failed to parse flags"
            , consoleError (E.string (D.errorToString err))
            )


view : Model -> Document Msg
view model =
    { title = "77 to Win"
    , body =
        (List.singleton << Element.layout pageAttrs) <|
            Element.column
                [ Element.height Element.fill
                , Element.centerX
                , Element.spacing 10
                ]
                [ header
                , mainContent model
                , footer
                ]
    }


header : Element msg
header =
    el
        [ Font.size 36
        , Element.centerX
        , Element.alignTop
        ]
        (text "77 to Win")


footer : Element msg
footer =
    el
        [ Font.size 10
        , Element.centerX
        , Element.alignBottom
        ]
        (Element.paragraph []
            [ text "See this site's source code at "
            , let
                url =
                    "https://github.com/joshuakb2/77-to-win"
              in
              Element.newTabLink []
                { url = url
                , label = text url
                }
            ]
        )


mapSelector : NormalModel -> Element Msg
mapSelector m =
    Element.row
        [ Element.centerX
        , Element.spacing 50
        ]
        [ chooseMapButton "Senate" Senate m.mapType
        , chooseMapButton "House" House m.mapType
        , chooseMapButton "Congressional" Congress m.mapType

        -- , chooseMapButton "Board of Education" Education m.mapType
        ]


chooseMapButton : String -> MapType -> MapType -> Element Msg
chooseMapButton label chosenMap currentMap =
    Input.button
        (if chosenMap == currentMap then
            [ Font.bold, Font.underline ]

         else
            []
        )
        { onPress = Just (MapChosen chosenMap)
        , label = text label
        }


mainContent : Model -> Element Msg
mainContent model =
    case model of
        FatalError err ->
            text err

        Normal m ->
            let
                parties =
                    getPartiesForMapType m.mapType m.parties

                mapSide =
                    String.fromInt (getMapWidth m.windowWidth)
            in
            Element.column
                [ Element.spacing 10
                ]
                [ mapSelector m
                , partyTallyElement parties
                , mapOfTexas
                    [ attribute "width" mapSide
                    , attribute "height" mapSide
                    , attribute "districts" (getDistrictsString parties)
                    , attribute "map-type" (mapTypeToString m.mapType)
                    ]
                ]


getMapWidth : Int -> Int
getMapWidth windowWidth =
    min 800 (windowWidth - 20)


getPartiesForMapType : MapType -> AllMapsParties -> Array Party
getPartiesForMapType mapType =
    case mapType of
        Senate ->
            .senateParties

        House ->
            .houseParties

        Congress ->
            .congressParties



-- Education ->
--     .educationParties


updatePartiesForMapType : MapType -> (Array Party -> Array Party) -> AllMapsParties -> AllMapsParties
updatePartiesForMapType mapType f parties =
    case mapType of
        Senate ->
            { parties | senateParties = f parties.senateParties }

        House ->
            { parties | houseParties = f parties.houseParties }

        Congress ->
            { parties | congressParties = f parties.congressParties }



-- Education ->
--     { parties | educationParties = f parties.educationParties }


pageAttrs : List (Attribute msg)
pageAttrs =
    [ Font.family
        [ Font.typeface "Roboto"
        , Font.sansSerif
        ]
    ]


partyTallyElement : Array Party -> Element msg
partyTallyElement parties =
    let
        ( democrats, republicans ) =
            tallyParties (Array.toList parties)
    in
    Element.column [ Element.centerX ]
        [ el [ Font.color blue ] (text ("Democrats: " ++ String.fromInt democrats))
        , el [ Font.color red ] (text ("Republicans: " ++ String.fromInt republicans))
        ]


blue : Color
blue =
    Element.rgb 0 0 1


red : Color
red =
    Element.rgb 1 0 0


tallyParties : List Party -> ( Int, Int )
tallyParties parties =
    case parties of
        [] ->
            ( 0, 0 )

        Democrat :: rest ->
            Tuple.mapFirst ((+) 1) (tallyParties rest)

        Republican :: rest ->
            Tuple.mapSecond ((+) 1) (tallyParties rest)


mapOfTexas : List (Html.Attribute msg) -> Element msg
mapOfTexas attrs =
    el [] <| Element.html <| Html.node "map-of-texas" attrs []


getDistrictsString : Array Party -> String
getDistrictsString =
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


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model ) of
        ( FatalErrorOccurred err, _ ) ->
            ( FatalError err, Cmd.none )

        ( DistrictPartyChanged index party, Normal m ) ->
            let
                newParties =
                    updatePartiesForMapType m.mapType (Array.set index party) m.parties
            in
            ( Normal { m | parties = newParties }
            , Cmd.batch
                [ writeLocalStorage "parties" (encodeAllMapsParties newParties)

                -- , Nav.replaceUrl m.key (Url.toString (setDistrictsQueryParam newDistrictsString m.currentUrl))
                ]
            )

        ( MapChosen newMapType, Normal m ) ->
            ( Normal { m | mapType = newMapType }, Cmd.none )

        ( WindowResized width, Normal m ) ->
            ( Normal { m | windowWidth = width }, Cmd.none )

        ( Noop _, _ ) ->
            ( model, Cmd.none )

        ( _, FatalError _ ) ->
            ( model, Cmd.none )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ setDistrictParty
            (\( n, party ) -> DistrictPartyChanged n party)
            (\_ -> Noop "Invalid value passed into setDistrictParty port.")
        , windowResized WindowResized (\_ -> Noop "Invalid data sent to windowResized port.")
        ]


onUrlRequest : UrlRequest -> Msg
onUrlRequest urlReq =
    case urlReq of
        Internal url ->
            Noop ("Internal URL request received: " ++ Url.toString url)

        External url ->
            Noop ("External URL request received: " ++ url)


onUrlChange : Url -> Msg
onUrlChange url =
    Noop ("URL changed to " ++ Url.toString url)
