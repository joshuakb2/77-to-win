module Main exposing (main)

import Array exposing (Array)
import Browser exposing (Document, UrlRequest(..), application)
import Browser.Dom exposing (Element)
import Browser.Navigation as Nav
import DataTypes exposing (AllMapsParties, MapType(..), Party(..), allMapsPartiesDecoder, defaultAllMapsParties, defaultParties, encodeAllMapsParties, mapTypeToString)
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
    , windowHeight : Int
    , currentUrl : Url
    , mapType : MapType
    , parties : AllMapsParties
    , zoom : Zoom
    }


type Msg
    = DistrictPartyChanged Int Party
    | MapChosen MapType
    | ZoomChosen Zoom
    | WindowResized (Int, Int)
    | ResetPartiesButtonClicked
    | FatalErrorOccurred String
    | Noop String

type Zoom
    = ZoomTexas
    | ZoomDFW
    | ZoomElPaso
    | ZoomCentral
    | ZoomRGV
    | ZoomHouston


flagDecoder : Decoder ( (Int, Int), AllMapsParties )
flagDecoder =
    D.map3 (\width height parties -> ((width, height), parties))
        (D.field "width" D.int)
        (D.field "height" D.int)
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
        Ok ( (width, height), parties ) ->
            ( Normal
                { key = key
                , windowWidth = width
                , windowHeight = height
                , currentUrl = url
                , mapType = mapType
                , parties = parties
                , zoom = ZoomTexas
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
        [ Font.size 12
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
                maybeParties =
                    getPartiesForMapType m.mapType m.parties

                effectiveParties =
                    maybeParties
                        |> Maybe.withDefault (defaultParties m.mapType)

                mapSide =
                    String.fromInt (getMapWidth m.windowWidth m.windowHeight)
            in
            Element.column
                [ Element.spacing 10
                , Element.centerX
                ]
                [ mapSelector m
                , partyTallyElement effectiveParties
                , mapOfTexas
                    [ attribute "width" mapSide
                    , attribute "height" mapSide
                    , attribute "districts" (getDistrictsString effectiveParties)
                    , attribute "map-type" (mapTypeToString m.mapType)
                    , attribute "zoom" (zoomData m.zoom m.mapType)
                    ]
                , zoomSelector m.zoom (m.windowWidth - 40)
                , customOrActual maybeParties
                ]


zoomSelector : Zoom -> Int -> Element Msg
zoomSelector currentZoom maxWidth =
    Element.wrappedRow [ Element.spacing 20, Element.centerX, Element.width (Element.maximum maxWidth Element.fill) ]
        [ selectZoom ZoomTexas currentZoom
        , selectZoom ZoomDFW currentZoom
        , selectZoom ZoomElPaso currentZoom
        , selectZoom ZoomCentral currentZoom
        , selectZoom ZoomRGV currentZoom
        , selectZoom ZoomHouston currentZoom
        ]

selectZoom : Zoom -> Zoom -> Element Msg
selectZoom chosenZoom currentZoom =
    Input.button (centerX ++ (sidePadding "5px") ++ (if chosenZoom == currentZoom then [ Font.underline, Font.bold ] else []))
        { onPress = Just (ZoomChosen chosenZoom)
        , label = text (zoomName chosenZoom)
        }

centerX : List (Attribute msg)
centerX =
    [ Element.htmlAttribute (Html.Attributes.style "margin-left" "auto")
    , Element.htmlAttribute (Html.Attributes.style "margin-right" "auto")
    ]

sidePadding : String -> List (Attribute msg)
sidePadding value =
    [ Element.htmlAttribute (Html.Attributes.style "padding-left" value)
    , Element.htmlAttribute (Html.Attributes.style "padding-right" value)
    ]

customOrActual : Maybe (Array Party) -> Element Msg
customOrActual maybeParties =
    let
        content =
            case maybeParties of
                Nothing ->
                    text "Showing actual parties for each district"

                Just _ ->
                    Element.column []
                        [ text "Showing custom parties"
                        , Input.button [ Element.centerX ]
                            { onPress = Just ResetPartiesButtonClicked
                            , label = text "Click here to reset"
                            }
                        ]
    in
    el [ Element.centerX ] content


getMapWidth : Int -> Int -> Int
getMapWidth windowWidth windowHeight =
    min 800
        <| min
            (windowWidth - 20)
            (windowHeight - 100)


getPartiesForMapType : MapType -> AllMapsParties -> Maybe (Array Party)
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
updatePartiesForMapType mapType f allMapsParties =
    let
        effectiveParties maybeParties =
            case maybeParties of
                Nothing ->
                    defaultParties mapType

                Just parties ->
                    parties
    in
    case mapType of
        Senate ->
            { allMapsParties | senateParties = Just (f (effectiveParties allMapsParties.senateParties)) }

        House ->
            { allMapsParties | houseParties = Just (f (effectiveParties allMapsParties.houseParties)) }

        Congress ->
            { allMapsParties | congressParties = Just (f (effectiveParties allMapsParties.congressParties)) }


resetPartiesForMapType : MapType -> AllMapsParties -> AllMapsParties
resetPartiesForMapType mapType parties =
    case mapType of
        Senate ->
            { parties | senateParties = Nothing }

        House ->
            { parties | houseParties = Nothing }

        Congress ->
            { parties | congressParties = Nothing }



-- Education ->
--     { parties | educationParties = f parties.educationParties }


pageAttrs : List (Attribute msg)
pageAttrs =
    [ Font.family
        [ Font.typeface "Roboto"
        , Font.sansSerif
        ]
    , Element.clipX
    , Element.clipY
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
    el [ Element.centerX ] <| Element.html <| Html.node "map-of-texas" attrs []


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

        ( WindowResized (width, height), Normal m ) ->
            ( Normal { m | windowWidth = width, windowHeight = height }, Cmd.none )

        ( ResetPartiesButtonClicked, Normal m ) ->
            let
                newParties =
                    resetPartiesForMapType m.mapType m.parties
            in
            ( Normal { m | parties = newParties }
            , writeLocalStorage "parties" (encodeAllMapsParties newParties) )

        ( ZoomChosen zoom, Normal m ) ->
            ( Normal { m | zoom = zoom }, Cmd.none)

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

zoomName : Zoom -> String
zoomName zoom =
    case zoom of
        ZoomTexas -> "Texas"
        ZoomDFW -> "DFW"
        ZoomElPaso -> "El Paso"
        ZoomCentral -> "Central Texas"
        ZoomRGV -> "RGV"
        ZoomHouston -> "Houston"

zoomData : Zoom -> MapType -> String
zoomData zoom mapType =
    case zoom of
        ZoomTexas -> "1,1,1"
        ZoomDFW -> "-0.022050140437043914,2.4377098256322998,5"
        ZoomElPaso -> "4.679380505573358,1.23961830427205,4"
        ZoomCentral -> "0.6933849578688869,-0.43770982563229965,6"
        ZoomRGV -> "0.6933849578688869, -1.6358013469925492,4"
        ZoomHouston ->
            if mapType == Senate
            then "-1.7595353791800188,-0.6773281299043497,7"
            else "-1.4424264569648262,-0.717414979839807,7"
