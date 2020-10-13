module Main exposing (main)

import Array exposing (Array)
import Browser exposing (Document, UrlRequest(..), application)
import Browser.Dom exposing (Element)
import Browser.Navigation as Nav
import DataTypes exposing (Party(..), partyStringDecoder)
import Element exposing (Attribute, Element, el, text)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Html exposing (Html)
import Html.Attributes exposing (attribute, default)
import Json.Decode as D exposing (Decoder, Value)
import Json.Encode as E
import Ports exposing (consoleError, setDistrictParty, writeLocalStorage)
import Url exposing (Url)
import Url.Parser


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
    | Normal
        { key : Nav.Key
        , districts : Array Party
        , windowWidth : Int
        , currentUrl : Url
        , mapType : MapType
        }


type MapType
    = Senate
    | House
    | Congress


mapTypeToString : MapType -> String
mapTypeToString mapType =
    case mapType of
        Senate ->
            "senate"

        House ->
            "house"

        Congress ->
            "congress"


districtCount : MapType -> Int
districtCount mapType =
    case mapType of
        Senate ->
            31

        House ->
            150

        Congress ->
            36


type Msg
    = DistrictPartyChanged Int Party
    | MapToggled
    | FatalErrorOccurred String
    | Noop String


flagDecoder : MapType -> Decoder ( Int, Array Party )
flagDecoder mapType =
    D.map2 Tuple.pair
        (D.field "width" D.int)
        (D.oneOf
            [ D.field "districts" partyStringDecoder
            , D.succeed (defaultDistricts mapType)
            ]
        )


defaultDistricts : MapType -> Array Party
defaultDistricts mapType =
    Array.initialize (districtCount mapType) (always Republican)


init : Value -> Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        mapType =
            Senate
    in
    case D.decodeValue (flagDecoder mapType) flags of
        Ok ( width, districts ) ->
            ( Normal
                { key = key
                , districts = districts
                , windowWidth = width
                , currentUrl = url
                , mapType = mapType
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
                ]
                [ header
                , mainContent model
                , toggleMapButton
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


mainContent : Model -> Element msg
mainContent model =
    case model of
        FatalError err ->
            text err

        Normal m ->
            el []
                (Element.html
                    (mapOfTexas
                        [ attribute "width" "800"
                        , attribute "height" "800"
                        , attribute "districts" (getDistrictsString m.districts)
                        , attribute "map-type" (mapTypeToString m.mapType)
                        ]
                    )
                )


toggleMapButton : Element Msg
toggleMapButton =
    Input.button []
        { label = text "Toggle loaded map"
        , onPress = Just MapToggled
        }


pageAttrs : List (Attribute msg)
pageAttrs =
    [ Font.family
        [ Font.typeface "Roboto"
        , Font.sansSerif
        ]
    ]


mapOfTexas : List (Html.Attribute msg) -> Html msg
mapOfTexas attrs =
    Html.node "map-of-texas" attrs []


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
                newDistricts =
                    Array.set index party m.districts
            in
            ( Normal { m | districts = newDistricts }
            , let
                newDistrictsString =
                    getDistrictsString newDistricts
              in
              Cmd.batch
                [ writeLocalStorage "districts" (E.string newDistrictsString)

                -- , Nav.replaceUrl m.key (Url.toString (setDistrictsQueryParam newDistrictsString m.currentUrl))
                ]
            )

        ( MapToggled, Normal m ) ->
            let
                newMapType =
                    if m.mapType == Senate then
                        House

                    else
                        Senate

                newDistricts =
                    defaultDistricts newMapType
            in
            ( Normal
                { m
                    | mapType = newMapType
                    , districts = newDistricts
                }
            , Cmd.none
            )

        ( Noop _, _ ) ->
            ( model, Cmd.none )

        ( _, FatalError _ ) ->
            ( model, Cmd.none )



-- setDistrictsQueryParam : String -> Url -> Url
-- setDistrictsQueryParam districts url =
--     { url | query =
--         case url.query of
--             Nothing ->
--                 Just ("districts=" ++ districts)
--             Just q ->
--                 Url.Parser.parse (replacementParser "districts" districts)
--     }


subscriptions : Model -> Sub Msg
subscriptions model =
    setDistrictParty
        (\( n, party ) -> DistrictPartyChanged n party)
        (\_ -> FatalErrorOccurred "Invalid value passed into setDistrictParty port.")


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
